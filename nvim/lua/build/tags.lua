local project = require("build.project");

local MODULE = {};

local PROJECT_TAGS_FILE_NAME = ".tags";

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

local running = false;
local pending = false;

local function project_tags_path()
  return vim.fs.joinpath(project.Root(), PROJECT_TAGS_FILE_NAME);
end

local function system_tags_directory()
  if system.Os() == "Windows" then
    return vim.fs.joinpath(vim.uv.os_homedir(), ".cache", "tags");
  end

  local cache = vim.env.XDG_CACHE_HOME;
  if not cache or cache == "" then
    cache = vim.fs.joinpath(vim.uv.os_homedir(), ".cache");
  end

  return vim.fs.joinpath(cache, "tags");
end

local function add_system_tags()
  local directory = system_tags_directory();
  local names = {
    system.Os() == "Windows" and "windows-c.tags" or "linux-c.tags";
    "system.tags";
  };

  for _, name in ipairs(names) do
    local path = vim.fs.joinpath(directory, name);
    if vim.fn.filereadable(path) == 1 then
      vim.opt.tags:append(path);
      break;
    end
  end

  local vulkan_tags = vim.fs.joinpath(directory, "vulkan.tags");
  if vim.fn.filereadable(vulkan_tags) == 1 then
    vim.opt.tags:append(vulkan_tags);
  end
end

local function generate(options)
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
        generate({ silent = true; });
      end
    end);
  end);

  return true;
end

function MODULE.Ensure()
  local tags_file = project_tags_path();
  if vim.fn.filereadable(tags_file) == 1 then
    return tags_file;
  end

  generate({ silent = true; });
  system.LogWarn("Tags are being generated. Retry when complete.");

  return nil;
end

vim.opt.tags:prepend("./.tags;");
add_system_tags();

vim.api.nvim_create_user_command("TagsUpdate", function()
  generate();
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
      generate({ silent = true; });
    end
  end;
});

return MODULE;
