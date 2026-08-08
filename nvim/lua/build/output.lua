local style   = require("build.style");
local process = require("build.process");
local result  = require("build.result");
local flush   = require("flush");

local _MODULE = {};

local STATE = {
  window  = nil;
  buffer  = nil;
  process = nil;
  flush   = nil;

  info = {
    lines  = 0;
    title  = "Program output";
    name   = "Program";
    status = "idle";
    group  = "RnobaPanelMuted";
  };
};

local function window_resize(line_count)
  local window = STATE.window;
  if window == nil or not vim.api.nvim_win_is_valid(window) then
    return;
  end

  if vim.api.nvim_get_current_win() ~= window then
    vim.api.nvim_win_set_cursor(window, { math.max(1, line_count); 0; });
  end

  if line_count ~= STATE.info.lines then
    vim.api.nvim_win_set_height(window, math.min(math.max(line_count, 3), 10));
    STATE.info.lines = line_count;
  end
end

local function winbar_frame()
  if STATE.window ~= nil and vim.api.nvim_win_is_valid(STATE.window) then
    style.Winbar(
      STATE.window,
      STATE.info.title .. " · " .. STATE.info.name,
      STATE.info.status,
      STATE.info.group
    );
  end
end

local function state_release(buffer)
  if STATE.buffer ~= buffer then
    return;
  end

  local current = STATE.process;
  local writer  = STATE.flush;
  STATE.window  = nil;
  STATE.buffer  = nil;
  STATE.flush   = nil;
  if writer then
    writer.close();
  end

  if current and process.Running(current) then
    if not process.Stop(current) then
      base.LogError("Could not stop the active program.");
      return;
    end
  end

  STATE.process = nil;
end

local function buffer_disable_editing(buffer)
  local normal = {
    "i"; "I"; "a"; "A"; "o"; "O"; "<Insert>";
    "c"; "C"; "d"; "D"; "s"; "S";
    "x"; "X"; "r"; "R"; "p"; "P";
    "u"; "<C-r>"; "<C-a>"; "<C-x>";
    "."; "~"; "J";
    "gJ"; "g~"; "gu"; "gU";
    "="; "<"; ">"; "!";
    "&"; "g&";
  };

  local visual = {
    "c"; "C"; "d"; "D"; "s"; "S";
    "x"; "X"; "r"; "p"; "P";
    "u"; "U"; "~";
    "="; "<"; ">"; "!";
  };

  local options = {
    buffer = buffer;
    silent = true;
    nowait = true;
  };

  for _, key in ipairs(normal) do
    vim.keymap.set("n", key, "<Nop>", options);
  end

  for _, key in ipairs(visual) do
    vim.keymap.set("x", key, "<Nop>", options);
  end
  vim.keymap.set("n", ":", "<Nop>", {
    buffer = buffer;
    silent = true;
  });

  vim.keymap.set("n", "@", "<Nop>", {
    buffer = buffer;
    silent = true;
  });
end

local function window_create()
  local parent = vim.api.nvim_get_current_win();
  vim.cmd("botright 3split");
  local window = vim.api.nvim_get_current_win();
  local buffer = vim.api.nvim_create_buf(false, true);
  buffer_disable_editing(buffer);
  vim.api.nvim_win_set_buf(window, buffer);

  STATE.window = window;
  STATE.buffer = buffer;
  style.Window(window);

  vim.api.nvim_create_autocmd({ "BufWipeout"; "BufDelete"; }, {
    buffer   = buffer;
    once     = true;
    callback = function()
      state_release(buffer);
    end
  });

  if vim.api.nvim_win_is_valid(parent) then
    vim.api.nvim_set_current_win(parent);
  end

  return window, buffer;
end

local function close()
  local window  = STATE.window;
  local writer  = STATE.flush;
  local current = STATE.process;

  if current and process.Running(current) and not process.Stop(current) then
    return false;
  end

  STATE.window  = nil;
  STATE.process = nil;
  STATE.flush   = nil;
  STATE.buffer  = nil;

  if writer then
    writer.close();
  end

  if window ~= nil and vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_win_close(window, true);
  end

  return true;
end

local function open(options)
  if not close() then
    return nil, "Could not stop the active program.";
  end

  STATE.info = {
    lines  = 0;
    title  = options.title or "Program output";
    name   = options.name  or vim.fn.fnamemodify(options.command[1], ":t");
    status = "running";
    group  = "RnobaPanelMuted";
  };
  local window, buffer = window_create();
  vim.bo[buffer].buflisted  = false;
  vim.bo[buffer].swapfile   = false;
  vim.bo[buffer].modified   = false;
  vim.bo[buffer].modifiable = false;
  vim.bo[buffer].bufhidden  = "wipe";
  vim.bo[buffer].undolevels = -1;
  vim.bo[buffer].filetype   = "program-output";
  vim.bo[buffer].buftype    = "nofile";
  local function stop_or_close()
    if STATE.process and process.Running(STATE.process) then
      _MODULE.Stop();
    else
      _MODULE.Close();
    end
  end

  winbar_frame();
  base.Map("<Esc>", stop_or_close, "Stop or close program output", buffer);
  base.Map("<C-c>", stop_or_close, "Stop or close program output", buffer);

  local writer           = flush.New(buffer, 64*1024, window_resize);
  local current, message = process.Run({
    command = options.command;
    cwd     = options.cwd;
    stream  = true;
    on_stderr = function(data) writer.push(data); end;
    on_stdout = function(data) writer.push(data); end;
    on_finish = function(completed)
      if STATE.process ~= completed then
        return;
      end
      writer.render();
      writer.close();
      if STATE.flush == writer then
        STATE.flush = nil;
      end

      STATE.process = nil;
      if completed.cancelled then
        STATE.info.status = "stopped";
        STATE.info.group  = "RnobaPanelWarn";
      else
        local parsed = result.Program(completed);
        STATE.info.status = parsed.status;
        STATE.info.group  = parsed.group;
      end
      winbar_frame();
    end;
  });

  STATE.flush   = writer;
  STATE.process = current;
  if not current then
    writer.close();

    STATE.flush       = nil;
    STATE.info.status = "failed to start";
    STATE.info.group  = "RnobaPanelError";

    winbar_frame();
    return nil, message;
  end
  return current;
end

local function stop()
  local result = true;
  if not process.Stop(STATE.process) then
    STATE.info.status = "could not stop";
    STATE.info.group  = "RnobaPanelError";
    result = false;
  else
    STATE.info.status = "stopping";
    STATE.info.group  = "RnobaPanelWarn";
  end

  winbar_frame();
  return result;
end

local function running()
  return process.Running(STATE.process);
end

function _MODULE.Close()
  return close(); 
end

function _MODULE.Open(options)
  return open(options); 
end

function _MODULE.Running()
  return running();
end

function _MODULE.Stop()
  return stop();
end

-- vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
--   callback = function(event)
--     if not STATE.window or not STATE.flush or vim.api.nvim_get_current_win() ~= STATE.window then
--       return
--     end
--
--     if event.event == "WinEnter" then
--       STATE.flush.pause();
--     else
--       STATE.flush.resume();
--     end
--
--   end,
-- })

return _MODULE;
