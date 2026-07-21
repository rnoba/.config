local project = require("build.project");

local PROJECT_TAGS_FILE_NAME = ".tags";
local SYSTEM_TAGS_FILE_NAME  = ".system_tags";
local MODULE = {};

local C_SOURCE_PATTERNS = {
  "*.c";
  "*.h";
  "*.cc";
  "*.hh";
  "*.cpp";
  "*.hpp";
  "*.cxx";
  "*.hxx";
};

local function add_directory(result, seen, path)
  if not path or path == "" then
    return;
  end

  path = vim.fs.normalize(path);
  if vim.fn.isdirectory(path) ~= 1 then
    return;
  end

  local key = system.Os() == "Windows" and path:lower() or path;
  if seen[key] then
    return;
  end

  seen[key]          = true;
  result[#result + 1] = path;
end

local function add_environment_directories(result, seen, value, separator)
  for _, path in ipairs(vim.split(value or "", separator, {
    plain     = true;
    trimempty = true;
  }))
  do
    add_directory(result, seen, path);
  end
end

local function glob_directories(pattern)
  local result = vim.fn.glob(pattern, false, true);

  table.sort(result, function(left, right)
    return left > right;
  end);

  return result;
end

local function add_latest_directory(result, seen, pattern)
  for _, path in ipairs(glob_directories(pattern)) do
    if vim.fn.isdirectory(path) == 1 then
      add_directory(result, seen, path);
      return;
    end
  end
end

local function add_compiler_directories(result, seen, compiler, language)
  if not system.TestProgram(compiler) then
    return;
  end

  local process = vim.system({
    compiler;
    "-E";
    "-x";
    language;
    "-";
    "-v";
  }, {
    env = {
      LC_ALL = "C";
    };
    stdin = "";
    text  = true;
  }):wait();

  local output  = (process.stderr or "") .. "\n" .. (process.stdout or "");
  local reading = false;

  for line in output:gmatch("[^\r\n]+") do
    if line:find("search starts here:", 1, true) then
      reading = true;
    elseif reading and line:find("End of search list.", 1, true) then
      break;
    elseif reading then
      line = line:gsub("%s+%(framework directory%)$", "");
      add_directory(result, seen, vim.trim(line));
    end
  end
end

local function add_compiler_search_directories(result, seen)
  for _, group in ipairs({
    { { "cc"; "gcc"; "clang"; }; "c";   };
    { { "c++"; "g++"; "clang++"; }; "c++"; };
  })
  do
    for _, compiler in ipairs(group[1]) do
      if system.TestProgram(compiler) then
        add_compiler_directories(result, seen, compiler, group[2]);
        break;
      end
    end
  end
end

local function add_vulkan_directories(result, seen)
  if vim.env.VULKAN_SDK then
    add_directory(result, seen, vim.fs.joinpath(vim.env.VULKAN_SDK, "Include"));
    add_directory(result, seen, vim.fs.joinpath(vim.env.VULKAN_SDK, "include"));
    add_directory(result, seen, vim.fs.joinpath(vim.env.VULKAN_SDK, "x86_64", "include"));
  end

  if system.Os() == "Windows" then
    add_latest_directory(
      result,
      seen,
      vim.fs.joinpath("C:\\VulkanSDK", "*", "Include")
    );
    return;
  end

  local home = vim.uv.os_homedir();
  if home then
    add_latest_directory(
      result,
      seen,
      vim.fs.joinpath(home, "VulkanSDK", "*", "x86_64", "include")
    );
  end
end

local function add_windows_sdk_directories(result, seen, root)
  local include_root = vim.fs.joinpath(root, "Windows Kits", "10", "Include");

  for _, version_root in ipairs(glob_directories(vim.fs.joinpath(include_root, "*"))) do
    local count = #result;

    for _, name in ipairs({
      "ucrt";
      "shared";
      "um";
      "winrt";
      "cppwinrt";
    })
    do
      add_directory(result, seen, vim.fs.joinpath(version_root, name));
    end

    if #result > count then
      return;
    end
  end
end

local function add_windows_directories(result, seen)
  add_environment_directories(result, seen, vim.env.INCLUDE, ";");

  if vim.env.VCToolsInstallDir then
    add_directory(result, seen, vim.fs.joinpath(vim.env.VCToolsInstallDir, "include"));
  end

  local windows_sdk_directory = vim.env.WindowsSdkDir or vim.env.WindowsSDKDir;

  if windows_sdk_directory and vim.env.WindowsSDKVersion then
    for _, name in ipairs({
      "ucrt";
      "shared";
      "um";
      "winrt";
      "cppwinrt";
    })
    do
      add_directory(
        result,
        seen,
        vim.fs.joinpath(
          windows_sdk_directory,
          "Include",
          vim.env.WindowsSDKVersion,
          name
        )
      );
    end
  end

  local roots = {};

  for _, name in ipairs({
    "ProgramW6432";
    "ProgramFiles";
    "ProgramFiles(x86)";
  })
  do
    local root = vim.env[name];
    if root and root ~= "" then
      roots[#roots + 1] = root;
    end
  end

  for _, root in ipairs(roots) do
    add_directory(result, seen, vim.fs.joinpath(root, "LLVM", "include"));
    add_windows_sdk_directories(result, seen, root);
    add_latest_directory(
      result,
      seen,
      vim.fs.joinpath(
        root,
        "Microsoft Visual Studio",
        "*",
        "*",
        "VC",
        "Tools",
        "MSVC",
        "*",
        "include"
      )
    );
  end
end

local function add_linux_directories(result, seen)
  add_directory(result, seen, "/usr/local/include");
  add_directory(result, seen, "/usr/include");

  add_environment_directories(result, seen, vim.env.CPATH, ":");
  add_environment_directories(result, seen, vim.env.C_INCLUDE_PATH, ":");
  add_environment_directories(result, seen, vim.env.CPLUS_INCLUDE_PATH, ":");
end

local function system_tags_directories()
  local result = {};
  local seen   = {};

  if system.Os() == "Windows" then
    add_windows_directories(result, seen);
  else
    add_linux_directories(result, seen);
  end

  add_compiler_search_directories(result, seen);
  add_vulkan_directories(result, seen);

  return result;
end

local function system_tags_path()
  return vim.fs.joinpath(system.CacheDir(), SYSTEM_TAGS_FILE_NAME);
end

local function project_tags_path()
  return vim.fs.joinpath(project.Root(), PROJECT_TAGS_FILE_NAME);
end

local system_tags_running = false;
local system_tags_pending = false;

local function generate_system_tags(options)
  options = options or {};

  if not system.TestProgram("ctags") then
    if not options.silent then
      system.LogError("Required program not found: ctags");
    end

    return false;
  end

  if system_tags_running then
    system_tags_pending = true;
    return true;
  end

  local directories = system_tags_directories();
  if #directories == 0 then
    if not options.silent then
      system.LogError(system.Os() .. " system include directories were not found.");
    end

    return false;
  end

  local tags_file = system_tags_path();
  local command = {
    "ctags";
    "--languages=C,C++";
    "--sort=yes";
    "--c-kinds=+p";
    "-R";
    "-f";
    tags_file;
  };

  vim.list_extend(command, directories);
  system_tags_running = true;

  vim.system(command, {
    text = true;
  }, function(result)
    vim.schedule(function()
      system_tags_running = false;

      if result.code == 0 then
        if not options.silent then
          system.LogInfo("System tags updated: " .. tags_file);
        end
      elseif not options.silent then
        local message = vim.trim(table.concat({
          result.stderr or "";
          result.stdout or "";
        }, "\n"));

        system.LogError(message ~= "" and message or "System ctags generation failed");
      end

      if system_tags_pending then
        system_tags_pending = false;
        generate_system_tags({ silent = true; });
      end
    end);
  end);

  return true;
end

local running = false;
local pending = false;

function MODULE.Generate(options)
  options = options or {};

  if not system.TestProgram("ctags") then
    if not options.silent then
      system.LogError("Required program not found: ctags");
    end
    return false;
  end

  if running then
    pending = true;
    return true;
  end

  local root      = project.Root();
  local tags_file = vim.fs.joinpath(root, PROJECT_TAGS_FILE_NAME);

  running = true;

  vim.system({
    "ctags";
    "--languages=C,C++";
    "--sort=yes";
    "--exclude=.git";
    "--exclude=build";
    "--exclude=.cache";
    "-R";
    "-f";
    tags_file;
    ".";
  }, {
    cwd  = root;
    text = true;
  }, function(result)
    vim.schedule(function()
      running = false;

      if result.code == 0 then
        if not options.silent then
          system.LogInfo("Tags updated: " .. tags_file);
        end
      elseif not options.silent then
        local message = vim.trim(table.concat({
          result.stderr or "";
          result.stdout or "";
        }, "\n"));

        system.LogError(message ~= "" and message or "ctags failed");
      end

      if pending then
        pending = false;
        MODULE.Generate({ silent = true; });
      end
    end);
  end);

  return true;
end

function MODULE.Ensure()
  if vim.fn.filereadable(project_tags_path()) == 1 then
    return true;
  end

  MODULE.Generate({ silent = true; });
  system.LogWarn("Tags are being generated. Retry when complete.");
  return false;
end

vim.opt.tags:prepend(system_tags_path());
vim.opt.tags:prepend("./.tags;");

vim.api.nvim_create_user_command("TagsSystemUpdate", function()
  generate_system_tags();
end,
{
  desc = "Generate " .. system.Os() .. " system tags.";
});

vim.api.nvim_create_user_command("TagsUpdate", function()
  MODULE.Generate();
end, {
  desc = "Generate C/C++ project tags.";
});

vim.api.nvim_create_user_command("TagsClear", function()
  local tags_file = project_tags_path();

  if vim.fn.delete(tags_file) == 0 then
    system.LogInfo("Removed: " .. tags_file);
  else
    system.LogWarn("Could not remove: " .. tags_file);
  end
end, {
  desc = "Remove the project tags file.";
});

vim.api.nvim_create_autocmd("BufWritePost", {
  group   = vim.api.nvim_create_augroup("rnoba-ctags-update", { clear = true; });
  pattern = C_SOURCE_PATTERNS;
  callback = function()
    if vim.fn.filereadable(project_tags_path()) == 1 then
      MODULE.Generate({ silent = true; });
    end
  end;
});

return MODULE;
