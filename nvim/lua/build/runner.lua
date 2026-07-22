local process = require("build.process");
local project = require("build.project");
local result  = require("build.result");
local ui      = require("build.ui");

local build_begin         = 0;
local build_output_closed = false;

local function elapsed_time()
  local elapsed_ms = (vim.uv.hrtime() - build_begin) / 1e6;
  return string.format("%.2fs", elapsed_ms / 1000);
end

local function log_result(build_file, parsed)
  local message = build_file.name .. ": " .. parsed.message;

  if parsed.level == "error" then
    system.LogError(message);
  elseif parsed.level == "warn" then
    system.LogWarn(message);
  else
    system.LogInfo(message);
  end
end

local function finish_stopped(build_file, raw_result)
  if not build_output_closed then
    local parsed = result.Parse(raw_result);

    ui.RecordOutput(parsed.output, {
      name   = build_file.name;
      status = "stopped - " .. elapsed_time();
      group  = "RnobaPanelError";
    });
  end

  ui.ClearResults();
  build_output_closed = false;

  system.LogInfo(build_file.name .. ": Build stopped.");
end

local function finish(build_file, raw_result)
  local parsed = result.Parse(raw_result);

  ui.RecordOutput(parsed.output, {
    name   = build_file.name;
    status = parsed.status .. " - " .. elapsed_time();
    group  = parsed.group;
  });

  if #parsed.items > 0 then
    ui.OpenResults(parsed.items, {
      name = build_file.name;
      root = build_file.root;
    });
  else
    ui.ClearResults();
  end

  log_result(build_file, parsed);
end

local function build_stop(options)
  options = options or {};

  if not process.IsRunning() then
    if options.silent ~= true then
      system.LogWarn("No build is running.");
    end
    return;
  end

  if not process.Stop() then
    return;
  end

  build_output_closed = options.output_closed == true;
  system.LogInfo("Stopping build...");
end

local function build_run()
  if process.IsRunning() then
    system.LogWarn("A build is already running.");
    return;
  end

  local build_file, message = project.Resolve();
  if not build_file then
    system.LogError(message);
    return;
  end

  ui.SetOwner(
    vim.api.nvim_get_current_buf(),
    vim.api.nvim_get_current_win()
  );

  vim.cmd("silent! wall");
  ui.Reset();

  build_begin         = vim.uv.hrtime();
  build_output_closed = false;

  local started;
  started, message = process.Start(
    build_file.command,
    {
      cwd = build_file.root;
    },
    function(raw_result, stopped)
      if stopped then
        finish_stopped(build_file, raw_result);
      else
        finish(build_file, raw_result);
      end
    end
  );

  if not started then
    system.LogError(message);
    return;
  end

  ui.RecordOutput({}, {
    name   = build_file.name;
    status = "running";
    group  = "RnobaPanelWarn";
  });

  ui.OpenOutput({
    focus       = false;
    allow_empty = true;
    on_close = function()
      build_stop({
        output_closed = true;
        silent        = true;
      });
    end;
  });

  system.LogInfo("Building " .. build_file.name .. "...");
end

local function build_run_or_stop()
  if process.IsRunning() then
    build_stop();
  else
    build_run();
  end
end

vim.api.nvim_create_user_command("Build", build_run, {
  desc = "Build the current project.";
});

vim.api.nvim_create_user_command("BuildStop", build_stop, {
  desc = "Stop the current build.";
});

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("rnoba-project-build-mappings", {
    clear = true;
  });
  callback = function(event)
    if vim.bo[event.buf].buftype ~= "" then
      return;
    end

    system.Map(
      "<C-b>",
      build_run_or_stop,
      "Build or stop project",
      event.buf
    );
  end;
});
