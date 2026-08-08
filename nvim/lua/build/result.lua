local _MODULE = {};

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
  stream = stream:gsub("\r",   "\n");
  return vim.split(stream, "\n", { plain = true; trimempty = true });
end

local function build_output(completed)
  local lines = {};
  vim.list_extend(lines, clean_stream(completed.stderr));
  vim.list_extend(lines, clean_stream(completed.stdout));
  return lines;
end

local function parse_diagnostics(lines, root)
  local parse_lines  = lines;
  local error_format = COMPILER_ERROR_FORMAT;

  if root and root ~= "" then
    parse_lines = { "__RN_BUILD_ROOT__" .. vim.fs.normalize(root) };
    vim.list_extend(parse_lines, lines);
    error_format = "%D__RN_BUILD_ROOT__%f," .. error_format;
  end

  local ok, parsed = pcall(vim.fn.getqflist, { lines = parse_lines; efm = error_format });

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

local function failure_reason(completed)
  local code   = completed.code;
  local signal = completed.signal;

  if base.Os() == "Windows" then
    local exception = WINDOWS_EXCEPTIONS[code];
    if exception then
      return exception, true;
    end

    return "status " .. tostring(code), false;
  end

  if signal ~= 0 then
    return SIGNAL_NAMES[signal] or ("signal " .. tostring(signal)), true;
  end

  return "status " .. tostring(code), false;
end

local function program_failure(completed)
  local reason, crashed = failure_reason(completed);
  return crashed and "program crashed" or "program failed", reason;
end

local function build_failure(items, lines, completed)
  local parsed_error = has_errors(items);

  if not parsed_error then
    local reason = failure_reason(completed);

    table.insert(items, 1, {
      text = "Build process failed: " .. reason;
      type = "E";
    });

    for _, line in ipairs(lines) do
      items[#items + 1] = {
        text = line;
        type = "I";
      };
    end
  end

  return {
    success = false;
    items   = items;
  };
end

local function parse_build(completed, root)
  local lines = build_output(completed);
  local items = parse_diagnostics(lines, root);

  if completed.code ~= 0 or completed.signal ~= 0 or has_errors(items) then
    return build_failure(items, lines, completed);
  end

  return {
    success = true;
    items   = items;
  };
end

local function parse_program(completed)
  if completed.code == 0 and completed.signal == 0 then
    return {
      success = true;
      status  = "exited successfully";
      group   = "RnobaPanelSuccess";
    };
  end

  local status, reason = program_failure(completed);
  return {
    success = false;
    status  = status .. " · " .. reason;
    group   = "RnobaPanelError";
  };
end

function _MODULE.Program(completed)
  return parse_program(completed);
end

function _MODULE.Build(completed, root)
  return parse_build(completed, root);
end

return _MODULE;
