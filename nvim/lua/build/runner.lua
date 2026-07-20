local project = require("build.project");
local tags    = require("build.tags");
local ui      = require("build.ui");

local MODULE = {};

local COMPILER_ERROR_FORMAT = table.concat({
  "%E%f:%l:%c: fatal error: %m";
  "%E%f:%l:%c: error: %m";
  "%W%f:%l:%c: warning: %m";
  "%I%f:%l:%c: note: %m";

  "%E%f:%l: fatal error: %m";
  "%E%f:%l: error: %m";
  "%W%f:%l: warning: %m";
  "%I%f:%l: note: %m";

  "%E%f:%l:%c: %m";
  "%E%f:%l: %m";

  "%-G%.%#";
}, ",");

local running     = false;
local build_begin = 0;

local function clean_stream(stream)
  if not stream or stream == "" then
    return {};
  end

  stream = stream:gsub("\27%[[0-9;]*m", "");
  stream = stream:gsub("\r\n", "\n");
  stream = stream:gsub("\r", "\n");

  return vim.split(stream, "\n", {
    plain     = true;
    trimempty = true;
  });
end

local function diagnostic_lines(result)
  return vim.list_extend(
    clean_stream(result.stderr),
    clean_stream(result.stdout)
  );
end

local function diagnostics(lines)
  local parsed = vim.fn.getqflist({
    lines = lines;
    efm   = COMPILER_ERROR_FORMAT;
  });

  return vim.tbl_filter(function(item)
    return item.valid == 1;
  end, parsed.items or {});
end

local function fallback_items(lines, exit_code)
  if #lines == 0 then
    return {
      {
        text = "Build exited with status " .. exit_code;
        type = "E";
      };
    };
  end

  return vim.tbl_map(function(line)
    return {
      text = line;
      type = "E";
    };
  end, lines);
end

local function finish(build_file, root, result)
  running = false;

  local build_elapsed_ms = (vim.uv.hrtime() - build_begin) / 1e6;
  local elapsed = string.format("%.2fs", build_elapsed_ms / 1000);

  local output            = clean_stream(result.stdout);
  local diagnostic_output = diagnostic_lines(result);

  local items   = diagnostics(diagnostic_output);
  local success = result.code == 0;

  ui.RecordOutput(output, {
    name   = build_file.name;
    status = success and ("succeeded"        or "failed") .. " - " .. elapsed;
    group  = success and "RnobaPanelSuccess" or "RnobaPanelError";
  });

  if system.TestProgram("ctags") then
    tags.Generate({ silent = true; });
  end

  if success and #items == 0 then
    ui.ClearResults();

    if #output > 0 then
      ui.OpenOutput({ focus = false; });
    end

    system.LogInfo(build_file.name .. ": Build succeeded.");
    return;
  end

  if not success and #items == 0 then
    items = fallback_items(diagnostic_output, result.code);
  end

  ui.OpenResults(items, {
    name = build_file.name;
    root = root;
  });

  if success then
    ui.OpenOutput({
      focus       = false;
      allow_empty = true;
    });
    -- system.LogWarn("Build succeeded with compiler diagnostics.");
  -- else
  --   system.LogWarn("Build failed with status " .. result.code .. ".");
  end
end

function MODULE.Run()
  if running then
    system.LogWarn("A build is already running.");
    return;
  end

  local build_file = project.FindBuildFile();
  if not build_file then
    system.LogError(
      "Could not find '" .. project.BuildScriptName() .. "' or 'Makefile'."
    );
    return;
  end

  local command, message = project.Command(build_file);
  if not command then
    system.LogError(message);
    return;
  end

  ui.SetOwner(
    vim.api.nvim_get_current_buf(),
    vim.api.nvim_get_current_win()
  );

  vim.cmd("silent! wall");
  ui.Reset();

  running     = true;
  build_begin = vim.uv.hrtime(); 

  local root = vim.fs.dirname(build_file.path);

  system.LogInfo("Building " .. build_file.name .. "...");

  vim.system(command, {
    cwd  = root;
    text = true;
  }, function(result)
    vim.schedule(function()
      finish(build_file, root, result);
    end);
  end);

end

function MODULE.Setup()
  vim.api.nvim_create_user_command("Build", MODULE.Run, {
    desc = "Build the current project.";
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
        MODULE.Run,
        "Build project and show errors",
        event.buf
      );
    end;
  });
end

return MODULE;
