local MODULE = {};

local os_name  = vim.uv.os_uname().sysname;

local OS       = "None";
local HAS_LSP  = false;

if os_name:find("Linux", 1, true) then
  OS = "Linux";
elseif os_name:find("Windows", 1, true) then
  OS = "Windows";
end

function MODULE.LogError(message)
  vim.notify(message, vim.log.levels.ERROR);
end

function MODULE.LogInfo(message)
  vim.notify(message, vim.log.levels.INFO);
end

function MODULE.LogWarn(message)
  vim.notify(message, vim.log.levels.WARN);
end

function MODULE.Os()
  if OS == "None" then
    MODULE.LogError("system: OS not supported: " .. os_name); error("NOOOOOOO");
  end

  return OS;
end

function MODULE.Cwd()
  return vim.fn.getcwd();
end

function MODULE.RequireProgram(name)
  if vim.fn.executable(name) ~= 1 then
    MODULE.LogError("system: Required program not found: " .. name); error(name);
  end
end

function MODULE.TestProgram(name)
  if vim.fn.executable(name) ~= 1 then
    return false;
  end
  return true;
end

function MODULE.BufferName(bufnr)
  bufnr = bufnr or 0;
  return vim.api.nvim_buf_get_name(bufnr);
end

function MODULE.BufferDirectory(bufnr)
  bufnr = bufnr or 0;

  local buffer_name = vim.api.nvim_buf_get_name(bufnr);

  if buffer_name ~= "" then
    return vim.fs.dirname(vim.fs.normalize(buffer_name));
  end

  return vim.fn.getcwd();
end

function MODULE.BufferKind(bufnr)
  bufnr = bufnr or 0;
  return vim.bo[bufnr].filetype;
end

function MODULE.JoinPath(a, b)
  return vim.fs.joinpath(a, b);
end

function MODULE.Map(keys, func, desc, buffer, mode)
  mode   = mode   or "n";
  buffer = buffer or nil;
  vim.keymap.set(mode, keys, func, {
    buffer = buffer,
    desc   = desc,
  });
end

function MODULE.SetLspAttached(value)
  HAS_LSP = value;
end

function MODULE.IsLspAttached()
  return HAS_LSP;
end

return MODULE;
