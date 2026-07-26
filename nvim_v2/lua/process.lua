local base = require("base");

local MODULE = {};

local SIGNAL_TERM = 15;

local function finish_process(process, options, code, signal)
  if process.done then
    return;
  end

  process.code    = tonumber(code)   or -1;
  process.signal  = tonumber(signal) or 0;
  process.success = process.code == 0 and process.signal == 0;
  process.done    = true;
  if options.on_finish then
    options.on_finish(process);
  end
end

local function schedule_finish(process, options, code, signal)
  vim.schedule(function()
    finish_process(
      process,
      options,
      code,
      signal
    );
  end);
end

local function spawn_job(process, options)
  local handle = vim.fn.jobstart(
    options.command,
    {
      cwd    = options.cwd;
      env    = options.env;
      pty    = options.pty;
      width  = vim.o.columns;
      height = vim.o.lines;
      on_stdout = options.on_stdout and function(_, data) options.on_stdout(data); end or nil;
      on_stderr = options.on_stderr and function(_, data) options.on_stderr(data); end or nil;
      on_exit = function(_, code)
        local signal = 0;
        if base.Os() ~= "Windows" and code >= 128 and code <= 255 then
          signal = code - 128;
        end
        schedule_finish(
          process,
          options,
          code,
          signal
        );
      end
    }
  );

  if handle <= 0 then
    error("jobstart() failed with status " .. tostring(handle));
  end

  process.handle = handle;
end

local function spawn_system(process, options)
  if options.on_stdout or options.on_stderr then
    error("kind = \"system\" does not stream output; " .. "use kind = \"job\"");
  end

  process.handle = vim.system(
    options.command,
    {
      cwd     = options.cwd;
      env     = options.env;
      text    = true;
      timeout = options.timeout;
    },
    function(result)
      vim.schedule(function()
        process.stdout = result.stdout or "";
        process.stderr = result.stderr or "";

        finish_process(
          process,
          options,
          result.code,
          result.signal
        );
      end);
    end
  );
end

local function spawn(options)
  local process = {
    kind   = options.kind;
    cwd    = options.cwd;
    handle = nil;
    stdout = nil;
    stderr = nil;
    code    = nil;
    signal  = 0;
    success = false;
    done    = false;
  };

  local ok, message = pcall(function()
    if options.kind == "system" then
      spawn_system(process, options);
      return;
    end

    if options.kind == "job" then
      spawn_job(process, options);
      return;
    end
    error("Unsupported process kind: " .. tostring(options.kind));
  end);

  if not ok then
    process.done    = true;
    process.code    = -1;
    process.success = false;

    return nil, tostring(message);
  end

  return process;
end

function MODULE.Run(options)
  options = options or {};

  options.kind = options.kind or "system";
  options.cwd  = options.cwd  or base.BufferDirectory();
  options.pty  = options.pty == true;

  if type(options.command) ~= "table" or #options.command == 0 then
    return nil, "No command provided.";
  end

  return spawn(options);
end

function MODULE.Stop(process)
  if process == nil or process.done or process.handle == nil then
    return false;
  end
  if process.kind == "job" then
    return vim.fn.jobstop(process.handle) == 1;
  end
  local ok = pcall(function() process.handle:kill(SIGNAL_TERM); end);
  return ok;
end

return MODULE;
