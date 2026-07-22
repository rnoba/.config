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

local function has_errors(items)
  for _, item in ipairs(items) do
    if tostring(item.type or ""):upper():sub(1, 1) == "E" then
      return true;
    end
  end

  return false;
end

local function process_failure(result)
  if system.Os() == "Windows" then
    local message = WINDOWS_EXCEPTIONS[result.code];
    if message then
      return "program failed", message;
    end
  end

  if result.signal and result.signal ~= 0 then
    local message = SIGNAL_NAMES[result.signal] or ("signal " .. result.signal);
    return "program failed", message;
  end

  return "process failed", "status " .. result.code;
end

local function add_process_failure(items, lines, message)
  table.insert(items, 1, {
    text = message;
    type = "E";
  });

  if #items > 1 then
    return;
  end

  for _, line in ipairs(lines) do
    items[#items + 1] = {
      text = line;
      type = "I";
    };
  end
end

function MODULE.Parse(result)
  local output = clean_stream(result.stdout);
  local lines  = diagnostic_lines(result);
  local items  = diagnostics(lines);

  if has_errors(items) then
    return {
      output  = output;
      items   = items;
      status  = "build failed";
      message = "Build failed.";
      group   = "RnobaPanelError";
      level   = "error";
    };
  end

  if result.code ~= 0 or (result.signal and result.signal ~= 0) then
    local status, reason = process_failure(result);
    local message        = status:gsub("^%l", string.upper) .. ": " .. reason;

    add_process_failure(items, lines, message);

    return {
      output  = output;
      items   = items;
      status  = status .. " · " .. reason;
      message = message .. ".";
      group   = "RnobaPanelError";
      level   = "error";
    };
  end

  if #items > 0 then
    return {
      output  = output;
      items   = items;
      status  = "succeeded with warnings";
      message = "Build succeeded with warnings.";
      group   = "RnobaPanelWarn";
      level   = "warn";
    };
  end

  return {
    output  = output;
    items   = {};
    status  = "succeeded";
    message = "Build succeeded.";
    group   = "RnobaPanelSuccess";
    level   = "info";
  };
end

return MODULE;
