local style = require("build.style");

local _MODULE = {};

local QUICKFIX_TEXT_FUNCTION = "v:lua.RnobaQuickFixText";
local QUICKFIX_ID            = nil;

local function item_kind(item)
  local  kind = tostring(item.type or ""):upper():sub(1, 1);
  return kind ~= "" and kind or "I";
end

local function item_text(item)
  return vim.trim(tostring(item.text or ""):gsub("[\r\n]+", " "));
end

local function count_label(count, singular, plural)
  if count == 0 then
    return nil;
  end
  return string.format("%d %s", count, count == 1 and singular or plural);
end

local function item_location(item, root)
  local path = "";

  if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
    path = vim.api.nvim_buf_get_name(item.bufnr);
  end

  path = base.RelativePath(root, path);
  if path == "" then
    return "";
  end

  if item.lnum and item.lnum > 0 then
    path = path .. ":" .. item.lnum;
    if item.col and item.col > 0 then
      path = path .. ":" .. item.col;
    end
  end

  return path;
end

local function quickfix_text(info)
  local list = vim.fn.getqflist({
    id      = info.id;
    items   = 0;
    context = 0;
  });

  local ctx = list.context or {};
  if ctx.rnoba_build ~= true then
    return {};
  end

  local items     = list.items or {};
  local width     = 0;
  local locations = {};
  for idx, item in ipairs(items) do
    local location = item_location(item, ctx.root);
    locations[idx] = location;
    width = math.max(width, vim.fn.strdisplaywidth(location));
  end
  width = math.min(width, 52);

  local lines = {};
  for idx = info.start_idx, info.end_idx do
    local item = items[idx];

    if not item then
      lines[#lines + 1] = "";
    else
      local location = locations[idx];

      local prefix = " " .. item_kind(item) .. " ";
      if width > 0 then
        local clipped = vim.fn.strcharpart(location, 0, width);
        local padding = math.max(0, width - vim.fn.strdisplaywidth(clipped));

        prefix = prefix .. clipped .. string.rep(" ", padding) .. " | ";
      end

      if item_kind(item) == "I" then
        prefix = " " .. prefix;
      end

      lines[#lines + 1] = prefix .. item_text(item);
    end

  end

  return lines;
end

_G.RnobaQuickFixText = quickfix_text;

local function list_summary(items)
  local counts = {
    info    = 0;
    error   = 0;
    warning = 0;
  };

  for _, item in ipairs(items) do
    local kind = item_kind(item);
    if kind == "W" then counts.warning = counts.warning + 1; end
    if kind == "E" then counts.error   = counts.error   + 1; end
    if kind == "I" then counts.info    = counts.info    + 1; end
  end

  local parts = {};
  parts[#parts + 1] = count_label(counts.error,   "error",    "errors");
  parts[#parts + 1] = count_label(counts.info,    "note",     "notes");
  parts[#parts + 1] = count_label(counts.warning, "warning",  "warnings");

  local group = "RnobaPanelMuted";
  if counts.warning > 0 then group = "RnobaPanelWarn";  end
  if counts.error   > 0 then group = "RnobaPanelError"; end

  return table.concat(parts, " · "), group;
end

local function close()
  vim.cmd("silent! cclose");
end

local function clear()
  close();

  vim.fn.setqflist({}, " ", {
    title   = "Build";
    items   = {};
    context = { rnoba_build = true };
    quickfixtextfunc = QUICKFIX_TEXT_FUNCTION;
  });

  QUICKFIX_ID = vim.fn.getqflist({ id = 0 }).id;
end

local function configure_window(window)
  if not vim.api.nvim_win_is_valid(window) then
    return;
  end

  local list = vim.fn.getqflist({ items = 0; context = 0; });
  local ctx  = list.context or {};
  if ctx.rnoba_build ~= true then
    return;
  end

  local buffer         = vim.api.nvim_win_get_buf(window);
  local summary, group = list_summary(list.items);

  style.Window(window, { cursorline = true; winfixheight = true });
  style.Winbar(window, "Build results · " .. (ctx.name or "Build"), summary, group);

  base.Map("<Esc>", close, "Close build results", buffer);
  base.Map("<C-c>", close, "Close build results", buffer);
end

local function open(items, options)
  options = options or {};

  vim.fn.setqflist({}, QUICKFIX_ID and "r" or " ", {
    id      = QUICKFIX_ID or 0;
    title   = "Build · " .. (options.name or "Build");
    items   = items or {};
    context = {
      name        = options.name or "Build";
      root        = options.root;
      rnoba_build = true;
    };
    quickfixtextfunc = QUICKFIX_TEXT_FUNCTION;
  });

  QUICKFIX_ID = vim.fn.getqflist({ id = 0 }).id;

  local list = vim.fn.getqflist({ size = 0; context = 0 });
  local ctx  = list.context or {};
  if ctx.rnoba_build ~= true or list.size == 0 then
    return;
  end

  local parent = vim.api.nvim_get_current_win();
  vim.cmd("botright copen");
  configure_window(vim.api.nvim_get_current_win());
  if vim.api.nvim_win_is_valid(parent) then
    vim.api.nvim_set_current_win(parent);
  end
end

function _MODULE.Open(items, options)
  open(items, options);
end

function _MODULE.Clear()
  clear();
end

function _MODULE.Close()
  close();
end

return _MODULE;
