local MODULE = {};

local SYSTEM_NAME = vim.uv.os_uname().sysname;
local OS = SYSTEM_NAME:find("Linux",   1, true) and "Linux"
        or SYSTEM_NAME:find("Windows", 1, true) and "Windows"
        or nil;

local function notify(message, level)
  vim.notify(vim.inspect(message), level);
end

function MODULE.LogError(message)
  notify(message, vim.log.levels.ERROR);
end

function MODULE.LogInfo(message)
  notify(message, vim.log.levels.INFO);
end

function MODULE.LogWarn(message)
  notify(message, vim.log.levels.WARN);
end

function MODULE.Os()
  if not OS then
    error("Unsupported operating system: " .. SYSTEM_NAME, 2);
  end

  return OS;
end

function MODULE.IsFileBuffer(buffer)
  buffer = buffer or 0;

  if not vim.api.nvim_buf_is_valid(buffer) then
    return false;
  end

  if vim.bo[buffer].buftype ~= "" then
    return false;
  end

  local path = vim.api.nvim_buf_get_name(buffer);
  return path ~= "" and vim.fn.isdirectory(path) == 0;
end

function MODULE.RelativePath(root, path)
  if not root or root == "" or not path or path == "" then
    return path or "";
  end

  return vim.fs.relpath(root, path);
end

function MODULE.BufferDirectory(buffer)
  buffer = buffer or 0;

  if vim.api.nvim_buf_is_valid(buffer) then
    local path = vim.api.nvim_buf_get_name(buffer);
    if path ~= "" then
      return vim.fs.dirname(vim.fs.normalize(path));
    end
  end

  return vim.fn.getcwd();
end

function MODULE.Map(keys, action, description, buffer, mode)
  local options = {
    desc   = description;
    silent = true;
  };

  if buffer ~= nil then
    options.buffer = buffer;
  end

  vim.keymap.set(mode or "n", keys, action, options);
end

return MODULE;
