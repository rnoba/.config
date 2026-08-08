local _MODULE = {};

local SIGNAL_KILL           = 9;
local SIGNAL_TERM           = 15;
local PROCESS_STOP_DELAY_MS = 2000;

local function system_finish(process, options, completed)
  if process.done then
    return;
  end

  process.code   = tonumber(completed.code)   or -1; 
  process.signal = tonumber(completed.signal) or 0; 
  process.handle = nil;
  process.done   = true;
  if not process.stream then
    process.stdout = completed.stdout or "";
    process.stderr = completed.stderr or "";
  end
  process.success = not process.cancelled
                    and process.code   == 0 
                    and process.signal == 0;
  if options.on_finish then
    options.on_finish(process);
  end
end

local function stream_handler(process, callback, err_field)
  if not callback then
    return false;
  end

  return function(err, data)
    if err then
      process[err_field] = tostring(err);
      return;
    end

    if data == nil then
      return;
    end

    callback(data);
  end
end

local function spawn(options)
  local process = {
    stream     = options.stream == true;
    handle     = nil;
    code       = nil;
    signal     = nil;

    stdout     = nil;
    stdout_err = nil;
    stderr     = nil;
    stderr_err = nil;

    done       = false;
    cancelled  = false;
    success    = false;
  };

  local system_options = {
    cwd     = options.cwd;
    env     = options.env;
    timeout = options.timeout;
    text    = options.text ~= false;
  };

  if process.stream then
    system_options.stdout = stream_handler(process, options.on_stdout, "stdout_err"); 
    system_options.stderr = stream_handler(process, options.on_stderr, "stderr_err"); 
  else
    system_options.stdout = true;
    system_options.stderr = true;
  end

  local ok, handle_or_err = pcall(
    vim.system,
    options.command,
    system_options,
    function(completed)
      vim.schedule(function()
        system_finish(process, options, completed);
      end);
    end
  );

  if not ok then
    return nil, tostring(handle_or_err);
  end

  process.handle = handle_or_err;
  return process;
end

local function running(process)
  return process ~= nil
         and not process.done
         and     process.handle ~= nil; 
end

local function stop(process)
  if not running(process) then
    return false;
  end

  if process.cancelled then
    return true;
  end

  local handle = process.handle;
  if base.Os() == "Windows" then
    local ok, killer = pcall(vim.system, {
      "taskkill";
      "/PID";
      tostring(handle.pid);
      "/T";
      "/F";
    });

    if not ok or not killer then
      return false;
    end
  else
    local ok = pcall(handle.kill, handle, SIGNAL_TERM);
    if not ok then
      return false;
    end
  end

  process.cancelled = true;

  if base.Os() ~= "Windows" then
    vim.defer_fn(
      function()
        if running(process) and handle == process.handle then
          pcall(handle.kill, handle, SIGNAL_KILL);
        end
      end,
      PROCESS_STOP_DELAY_MS
    );
  end

  return true;
end

function _MODULE.Run(options)
  options = options or {};

  if type(options.command) ~= "table" or #options.command == 0 then
    return nil, "No command provided.";
  end

  return spawn(options);
end

function _MODULE.Running(process)
  return running(process);
end

function _MODULE.Stop(process)
  return stop(process);
end

return _MODULE;
