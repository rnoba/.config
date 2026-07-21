local MODULE = {};

local VIM_OS_NAME = vim.uv.os_uname().sysname;
local OS          = "None";

if VIM_OS_NAME:find("Linux", 1, true) then
  OS = "Linux";
elseif VIM_OS_NAME:find("Windows", 1, true) then
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
    MODULE.LogError("system: OS not supported: " .. VIM_OS_NAME);
    error();
  end

  return OS;
end

function MODULE.TestProgram(name)
  return vim.fn.executable(name) == 1;
end

function MODULE.IsFileBuffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false;
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false;
  end
  local buffer_name = vim.api.nvim_buf_get_name(bufnr);
  if buffer_name == "" then
    return false;
  end
  if vim.fn.isdirectory(buffer_name) == 1 then
    return false;
  end
  return true;
end

function MODULE.BufferDirectory(bufnr)
  bufnr = bufnr or 0;
  local buffer_name = vim.api.nvim_buf_get_name(bufnr);
  if buffer_name ~= "" then
    return vim.fs.dirname(vim.fs.normalize(buffer_name));
  end

  return vim.fn.getcwd();
end

function MODULE.Map(keys, func, desc, buffer, mode)
  local opts = {
    desc   = desc,
    silent = true,
    nowait = true,
  };

  if buffer ~= nil then
    opts.buffer = buffer;
  end

  vim.keymap.set(mode or "n", keys, func, opts);
end

return MODULE;
