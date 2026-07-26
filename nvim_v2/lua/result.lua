local MODULE = {};

local WINDOWS_EXCEPTIONS = {
  [3221225477]  = "access violation (0xC0000005)";
  [-1073741819] = "access violation (0xC0000005)";
  [3221225725]  = "stack overflow (0xC00000FD)";
  [-1073741571] = "stack overflow (0xC00000FD)";
  [3221225620]  = "integer division by zero (0xC0000094)";
  [-1073741676] = "integer division by zero (0xC0000094)";
  [3221225617]  = "illegal instruction (0xC000001D)";
  [-1073741795] = "illegal instruction (0xC000001D)";
};

local SIGNAL_NAMES = {
  [4]  = "illegal instruction";
  [6]  = "aborted";
  [8]  = "floating-point exception";
  [9]  = "killed";
  [11] = "segmentation fault";
  [15] = "terminated";
};

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

  "%E%f: fatal error: %m";
  "%E%f: error: %m";
  "%W%f: warning: %m";

  "%E%f(%l\\,%c): fatal error %t%n: %m";
  "%E%f(%l\\,%c): error %t%n: %m";
  "%W%f(%l\\,%c): warning %t%n: %m";
  "%I%f(%l\\,%c): note: %m";

  "%E%f(%l): fatal error %t%n: %m";
  "%E%f(%l): error %t%n: %m";
  "%W%f(%l): warning %t%n: %m";
  "%I%f(%l): note: %m";

  "%E%f : fatal error %m";
  "%E%f : error %m";

  "%-G%.%#";
}, ",");

local function clean_stream(stream)
  if stream == nil or stream == "" then
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

local function process_output(result)
  local lines = {};
  vim.list_extend(lines, clean_stream(result.stderr));
  vim.list_extend(lines, clean_stream(result.stdout));
  return lines;
end

local function diagnostics(lines, cwd)
  local ok, parsed = pcall(function()
    return vim.fn.getqflist({
      lines = lines;
      efm   = COMPILER_ERROR_FORMAT;
    });
  end);

  if not ok then
    return {
      {
        text = "Could not parse compiler output: " .. tostring(parsed);
        type = "E";
      };
    };
  end

  return vim.tbl_filter(function(item) return item.valid == 1; end, parsed.items or {});
end

local function has_errors(items)
  for _, item in ipairs(items) do
    if tostring(item.type or ""):upper():sub(1, 1) == "E" then
      return true;
    end
  end

  return false;
end

local function build_failure(items, output, code)
  if not has_errors(items) then
    table.insert(items, 1, {
      text = "Build process exited with status " .. tostring(code);
      type = "E";
    });
  end

  if #items == 1 then
    for _, line in ipairs(output) do
      items[#items + 1] = {
        text = line;
        type = "I";
      };
    end
  end

  return {
    success = false;
    output  = output;
    items   = items;
    status  = "build failed";
    message = "Build failed.";
    group   = "RnobaPanelError";
    level   = "error";
  };
end

local function program_failure(result)
  local code = tonumber(result.code) or -1;

  if base.Os() == "Windows" then
    local message = WINDOWS_EXCEPTIONS[code];
    if message then
      return "program crashed", message;
    end
  end

  local signal = tonumber(result.signal) or 0;
  if signal ~= 0 then
    local message = SIGNAL_NAMES[signal] or ("signal " .. signal);
    return "program crashed", message;
  end

  return "program failed", "status " .. code;
end

function MODULE.ParseBuild(result)
  local output = process_output(result);
  local items  = diagnostics(output, result.cwd);
  local code   = tonumber(result.code) or -1;

  if has_errors(items) or code ~= 0 then
    return build_failure(items, output, code);
  end

  if #items > 0 then
    return {
      success = true;
      output  = output;
      items   = items;
      status  = "succeeded with warnings";
      message = "Build succeeded with warnings.";
      group   = "RnobaPanelWarn";
      level   = "warn";
    };
  end

  return {
    success = true;
    output  = output;
    items   = {};
    status  = "succeeded";
    message = "Build succeeded.";
    group   = "RnobaPanelSuccess";
    level   = "info";
  };
end

function MODULE.ParseProgram(result)
  local code   = tonumber(result.code)   or -1;
  local signal = tonumber(result.signal) or 0;
  if code == 0 and signal == 0 then
    return {
      success = true;
      status  = "exited successfully";
      message = "Program exited successfully.";
      group   = "RnobaPanelSuccess";
      level   = "info";
    };
  end
  local status, reason = program_failure(result);
  local message        = status:gsub("^%l", string.upper) .. ": " .. reason;
  return {
    success = false;
    status  = status  .. " · " .. reason;
    message = message .. ".";
    group   = "RnobaPanelError";
    level   = "error";
  };
end

return MODULE;
