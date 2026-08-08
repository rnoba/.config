local process  = require("build.process");
local output   = require("build.output");
local project  = require("build.project");
local result   = require("build.result");
local quickfix = require("build.quickfix");

local _MODULE = {};

local STATE = {
  main_window = nil;
  main_buffer = nil;
  task        = nil;
  closing     = false;
};

local function task_is_current(task)
  return task == STATE.task;
end

local function task_clear(task)
  if task_is_current(task) then
    STATE.task = nil;
  end
end

local function build_cancel(notify)
  local task = STATE.task;
  if not task then
    return false;
  end

  STATE.task = nil;
  if process.Running(task.process) and not process.Stop(task.process) then
    STATE.task = task; base.LogError("Could not stop the active build process.");
    return false;
  end

  if notify then
    local message = task.process and "Build stopped." or "Build cancelled.";
    base.LogInfo(message);
  end

  return true;
end

local function task_stop_active()
  if STATE.task then
    build_cancel(true);
    return true;
  end

  if not output.Running() then
    return false;
  end

  if not output.Stop() then
    base.LogError("Could not stop the active program.");
  end

  return true;
end

local function output_open(task, path)
  if not task_is_current(task) then
    return;
  end

  task_clear(task);
  if not path then
    base.LogWarn("Build succeeded, but no executable was found.");
    return;
  end

  local started, message = output.Open({
    command = { path };
    cwd     = task.build.root;
    name    = vim.fn.fnamemodify(path, ":t");
  });

  if not started then
    base.LogError(message);
  end
end

local function build_run()
  local build, message = project.BuildFile();
  if not build then
    base.LogError(message or "Could not determine how to build the project.");
    return;
  end

  local saved, save_error = pcall(vim.cmd, "wall");
  if not saved then
    base.LogError("Could not save buffers: " .. tostring(save_error));
    return;
  end

  quickfix.Clear();
  output.Close();

  STATE.main_window = vim.api.nvim_get_current_win();
  STATE.main_buffer = vim.api.nvim_win_get_buf(STATE.main_window);
  local current_task = {
    build    = build;
    process  = nil;
    snapshot = project.Snapshot(build.root);
  };

  STATE.task = current_task;
  local build_process, build_message = process.Run({
    command   = build.command;
    cwd       = build.root;
    on_finish = function(completed)
      if not task_is_current(current_task) or completed ~= current_task.process then
        return;
      end

      current_task.process = nil;
      if completed.cancelled then
        task_clear(current_task); return;
      end

      local parsed = result.Build(completed, current_task.build.root);
      if #parsed.items > 0 then
        quickfix.Open(parsed.items, { name = current_task.build.name; root = current_task.build.root });
      else
        quickfix.Close();
      end

      if not parsed.success then
        task_clear(current_task);
        return;
      end

      vim.schedule(function()
        if not task_is_current(current_task) then
          return;
        end

        project.Resolve(current_task.build.root, current_task.snapshot, function(path) output_open(current_task, path); end);
      end);

    end
  });

  if not build_process then
    task_clear(current_task);
    base.LogError(build_message or "Could not start the build process.");
    return;
  end

  current_task.process = build_process;
end

local function build_or_stop()
  if not task_stop_active() then
    build_run();
  end
end

local function close()
  if STATE.closing then
    return;
  end
  STATE.closing = true;
  build_cancel(false);
  if STATE.task then
    STATE.closing = false; return;
  end
  output.Close();
  quickfix.Close();
  STATE.main_window = nil;
  STATE.main_buffer = nil;
  STATE.closing     = false;
end

local MAPPING_GROUP = vim.api.nvim_create_augroup(
  "rnoba-project-build-mappings",
  { clear = true; }
);

vim.api.nvim_create_autocmd("BufEnter", {
  group = MAPPING_GROUP;
  callback = function(event)
    if base.IsFileBuffer(event.buf) then
      base.Map("<C-b>", build_or_stop, "Build, run, or stop project", event.buf);
    end
  end;
});

local PARENT_GROUP = vim.api.nvim_create_augroup(
  "rnoba-build-parent",
  { clear = true; }
);

vim.api.nvim_create_autocmd("QuitPre", {
  group    = PARENT_GROUP;
  callback = function()
    if STATE.main_window == vim.api.nvim_get_current_win() then
      close();
    end
  end;
});

vim.api.nvim_create_autocmd("BufWipeout", {
  group    = PARENT_GROUP;
  callback = function(event)
    if event.buf == STATE.main_buffer then
      close();
    end
  end;
});

vim.api.nvim_create_autocmd("VimLeavePre", {
  group    = PARENT_GROUP;
  callback = close;
});

return _MODULE;
