local MODULE = {};

local SIGNAL_TERM = 15;
local SIGNAL_KILL = 9;

local process       = nil;
local process_group = false;
local stopping      = false;

local function prepare_command(command)
  if system.Os() ~= "Linux" or not system.TestProgram("setsid") then
    return command, false;
  end

  local result = {
    "setsid";
    "--wait";
  };

  vim.list_extend(result, command);
  return result, true;
end

local function signal_process(current, signal)
  if current:is_closing() then
    return;
  end

  local ok, message = pcall(current.kill, current, signal);
  if not ok then
    system.LogError(tostring(message));
  end
end

local function signal_process_group(pid, signal)
  local result, message, name = vim.uv.kill(-pid, signal);
  if result == nil and name ~= "ESRCH" then
    system.LogError(tostring(message));
  end
end

local function force_stop(current)
  if process == current and not current:is_closing() then
    signal_process(current, SIGNAL_KILL);
  end
end

local function stop_windows(current)
  vim.system({
    "taskkill";
    "/PID";
    tostring(current.pid);
    "/T";
    "/F";
  }, {
    text = true;
  }, function(result)
    if result.code == 0 then
      return;
    end

    vim.schedule(function()
      force_stop(current);
    end);
  end);
end

local function stop_posix(current)
  if process_group then
    local pid = current.pid;

    signal_process_group(pid, SIGNAL_TERM);

    vim.defer_fn(function()
      signal_process_group(pid, SIGNAL_KILL);
    end, 1000);
    return;
  end

  signal_process(current, SIGNAL_TERM);

  vim.defer_fn(function()
    force_stop(current);
  end, 1000);
end

function MODULE.IsRunning()
  return process ~= nil;
end

function MODULE.Start(command, options, callback)
  if MODULE.IsRunning() then
    return false, "A build is already running.";
  end

  options = options or {};

  command, process_group = prepare_command(command);
  stopping = false;

  local current;
  local ok, value = pcall(function()
    current = vim.system(command, {
      cwd  = options.cwd;
      text = true;
    }, function(result)
      vim.schedule(function()
        if process ~= current then
          return;
        end

        local was_stopped = stopping;

        process       = nil;
        process_group = false;
        stopping      = false;

        callback(result, was_stopped);
      end);
    end);

    process = current;
  end);

  if not ok then
    process       = nil;
    process_group = false;
    stopping      = false;

    return false, tostring(value);
  end

  return true;
end

function MODULE.Stop()
  if not MODULE.IsRunning() or stopping then
    return false;
  end

  stopping = true;

  local current = process;

  if system.Os() == "Windows" then
    stop_windows(current);
  else
    stop_posix(current);
  end

  return true;
end

return MODULE;
