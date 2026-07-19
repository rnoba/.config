-- vim.opt.tags:prepend("./.tags;");

local C_SOURCE_PATTERNS = {
  "*.c",
  "*.h",
  "*.cc",
  "*.hh",
  "*.cpp",
  "*.hpp",
  "*.cxx",
  "*.hxx",
};

local BUILD_SCRIPT_NAME = "build.sh";
if system.Os() == "Windows" then
  BUILD_SCRIPT_NAME = "build.bat";
end

local function find_file(name)
  local matches = vim.fs.find(name, {
    path   =  system.BufferDirectory(),
    upward =  true,
    type   =  "file",
    stop   = vim.env.HOME,
  });
  return matches[1];
end

local function find_build_script(fallback) 
  local path = find_file(BUILD_SCRIPT_NAME); 
  if path then
    return path, false;
  end

  path = find_file(fallback);
  return path, path ~= nil;  
end

local function project_root()
  local build_script = find_build_script("Makefile"); 
  if build_script then
    return vim.fs.dirname(build_script);
  end

  return vim.fs.root(system.BufferDirectory(), {
    ".git",
  }) or system.Cwd();
end


local tags_running = false;
local tags_pending = false;
local function generate_tags(config)
  local options = options or {};

  system.RequireProgram("ctags");

  if tags_running then
    tags_pending = true;
    return;
  end

  local root  = project_root();
  local tags_file = system.JoinPath(root, ".tags"); 

  tags_running = true;
  vim.system({
    "ctags",
    "--languages=C,C++",
    -- "--extras=+q",
    "--exclude=.git",
    "--exclude=build",
    "--exclude=.cache",
    "-R",
    "-f",
    tags_file,
    ".",
  }, {
    cwd  = root,
    text = true,
  }, function(result)
    vim.schedule(function()
      tags_running = false;
      if result.code == 0 then
        if not options.silent then
          system.LogInfo("Tags updated: " .. tags_file);
        end
      else
        local message = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""));
        system.LogError((message ~= "") and message or "ctags failed");
      end

      if tags_pending then
        tags_pending = false;
        generate_tags({ silent = true });
      end
    end);
  end);
end

vim.api.nvim_create_user_command("TagsUpdate", function()
  generate_tags();
end, {
desc = "Generate C/C++ project tags."
});

vim.api.nvim_create_user_command("TagsClear", function()
  local root  = project_root();
  local tags_file = system.JoinPath(root, ".tags"); 
  if vim.fn.delete(tags_file) == 0 then
    system.LogInfo("Removed: " .. tags_file);
  else
    system.LogWarn("Could not remove: " .. tags_file);
  end
end, {
desc = "Remove the project tags file."
});

vim.api.nvim_create_autocmd("BufWritePost", {
  group    = vim.api.nvim_create_augroup("rnoba-ctags-update", { clear = true }),
  pattern  = C_SOURCE_PATTERNS,
  callback = function()
    local root  = project_root();
    local tags_file = system.JoinPath(root, ".tags"); 
    if vim.fn.filereadable(tags_file) == 1 then
      generate_tags({ silent = true });
    end
  end
});

local build_running = false;
local COMPILER_ERROR_FORMAT = table.concat({
  "%E%f:%l:%c: fatal error: %m",
  "%E%f:%l:%c: error: %m",
  "%W%f:%l:%c: warning: %m",
  "%I%f:%l:%c: note: %m",

  "%E%f:%l: fatal error: %m",
  "%E%f:%l: error: %m",
  "%W%f:%l: warning: %m",
  "%I%f:%l: note: %m",

  "%E%f:%l:%c: %m",
  "%E%f:%l: %m",

  "%-G%.%#",
}, ",");

local function open_build_results(items)
  vim.fn.setqflist({}, " ", {
    title = BUILD_SCRIPT_NAME,
    items = items, 
  });

  local ok, trouble = pcall(require, "trouble");

  if ok then
    trouble.open({
      mode  = "qflist",
      focus = true
    });
  else
    vim.cmd("copen");
  end
end

local function close_build_results()
  vim.fn.setqflist({}, " ", {
    title = BUILD_SCRIPT_NAME,
    items = {}, 
  });

  local ok, trouble = pcall(require, "trouble");

  if ok then
    trouble.close("qflist");
  else
    vim.cmd("cclose");
  end
end

local build_output_buffer = nil;
local build_output_window = nil;
local function show_build_output(output)
  if build_output_window and vim.api.nvim_win_is_valid(build_output_window) then
    return;
  end

  local height = math.min(math.max(#output, 3), 30);

  local buffer      = vim.api.nvim_create_buf(false, true);
  build_output_buffer = buffer;
  vim.cmd("belowright split");
  local window      = vim.api.nvim_get_current_win();
  build_output_window = window;

  vim.api.nvim_win_set_height(window, height);
  vim.api.nvim_win_set_buf(0, buffer);

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buffer,
    once   = true,
    callback = function()
      build_output_buffer = nil;
      build_output_window = nil;
    end,
  });

  vim.bo[buffer].buftype   = "nofile";
  vim.bo[buffer].bufhidden = "wipe";
  vim.bo[buffer].swapfile  = false;
  vim.bo[buffer].modifiable = true;
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, output);
  vim.bo[buffer].modifiable = false;
  vim.bo[buffer].readonly   = true;
end

local function close_build_output()
  if build_output_window and vim.api.nvim_win_is_valid(build_output_window) then
    vim.api.nvim_win_close(build_output_window, true);
  end
  build_output_window = nil;
  build_output_buffer = nil;
end

local function run_build()
  if build_running then
    system.LogWarn("A build is already running.");
    return;
  end

  local build_script, fallback = find_build_script("Makefile");
  if not build_script then
    system.LogError("Could not find build file \'" .. BUILD_SCRIPT_NAME .. "\' or Makefile.");
    return;
  end

  local build_commands = nil;
  if fallback then
    system.RequireProgram("make");
    build_commands = {
      "make",
      "-f",
      build_script,
    };
  elseif system.Os() == "Linux" then
    system.RequireProgram("bash");
    build_commands = {
      "bash",
      build_script
    };
  elseif system.Os() == "Windows" then
    system.RequireProgram("cmd");
    build_commands = {
      "cmd",
      "/C",
      build_script,
    };
  else
    system.LogError("Os not supported.");
    return;
  end

  vim.cmd("silent! wall"); system.LogInfo("Building...");
  build_running = true;
  local root    = project_root();
  vim.system(build_commands, {
    cwd  = root,
    text = true,
  }, function(result)
    vim.schedule(function()
      build_running = false;
      local output = table.concat({
        result.stdout or "",
        result.stderr or "",
      }, "\n");

      local lines  = vim.split(output, "\n", { plain = true, trimempty = true });
      local parsed = vim.fn.getqflist({ lines = lines, efm = COMPILER_ERROR_FORMAT });

      local items = vim.tbl_filter(function(item)
        return item.valid == 1;
      end, parsed.items or {});

      generate_tags({ silent = true });

      if result.code == 0 and #items == 0 then
        system.LogInfo(build_script .. ": Build succeeded.");
        close_build_results();

        if #lines ~= 0 then
          close_build_output(); show_build_output(lines);
        end
        return;
      end

      if result.code ~= 0 and #items == 0 then
        items = vim.tbl_map(function(line) return { text = line, type = "E", } end, lines);
        if #items == 0 then
          items = { { text = BUILD_SCRIPT_NAME .. " exited with status: " .. result.code, type = "E" } };
        end
      end

      open_build_results(items);
      if #lines ~= 0 then
        close_build_output(); show_build_output(lines);
      end

      if result.code == 0 then
        system.LogWarn("Build succeeded with compiler diagnostics.");
      else
        system.LogError("Build failed with status " .. result.code);
      end
    end);
  end);
end

vim.keymap.set("n", "<C-b>", run_build, {
  desc = "Build project and show errors",
});
