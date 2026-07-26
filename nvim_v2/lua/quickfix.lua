local style = require("style");

local MODULE = {};

local function item_kind(item)
  local kind = tostring(item.type or ""):upper():sub(1, 1);
  return kind ~= "" and kind or "I";
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

local function item_text(item)
  return vim.trim(tostring(item.text or ""):gsub("[\r\n]+", " "));
end

function text(info)
  local list = vim.fn.getqflist({
    id      = info.id;
    items   = 0;
    context = 0;
  });

  local context = list.context or {};
  if context.rnoba_build ~= true then
    return {};
  end

  local items     = list.items or {};
  local locations = {};
  local width     = 0;

  for index, item in ipairs(items) do
    local location   = item_location(item, context.root);
    locations[index] = location;

    width = math.max(width, vim.fn.strdisplaywidth(location));
  end

  width = math.min(width, 52);

  local lines = {};
  for index = info.start_idx, info.end_idx do
    local item = items[index];

    if not item then
      lines[#lines + 1] = "";
    else
      local location = locations[index] or "";
      local prefix   = " " .. item_kind(item) .. "  ";

      if width > 0 then
        local clipped = vim.fn.strcharpart(location, 0, width);
        local padding = math.max(0, width - vim.fn.strdisplaywidth(clipped));
        prefix = prefix .. clipped .. string.rep(" ", padding) .. " │ ";
      end

      lines[#lines + 1] = prefix .. item_text(item);
    end
  end

  return lines;
end

local function count_label(count, singular, plural)
  if count == 0 then
    return nil;
  end

  return string.format("%d %s", count, count == 1 and singular or plural);
end

function summary(items)
  local counts = {
    error   = 0;
    warning = 0;
    info    = 0;
  };

  for _, item in ipairs(items) do
    local kind = item_kind(item);

    if kind == "E" then
      counts.error = counts.error + 1;
    elseif kind == "W" then
      counts.warning = counts.warning + 1;
    else
      counts.info = counts.info + 1;
    end
  end

  local parts = {
    count_label(counts.error,   "error",   "errors");
    count_label(counts.warning, "warning", "warnings");
    count_label(counts.info,    "note",    "notes");
  };

  local filtered = vim.tbl_filter(function(value)
    return value ~= nil;
  end, parts);

  local group = "RnobaPanelMuted";
  if counts.error > 0 then
    group = "RnobaPanelError";
  elseif counts.warning > 0 then
    group = "RnobaPanelWarn";
  end

  return table.concat(filtered, " · "), group;
end

local function configure(window)
  if not vim.api.nvim_win_is_valid(window) then
    return;
  end

  local list = vim.fn.getqflist({
    items   = 0;
    context = 0;
  });
  local context = list.context or {};
  if context.rnoba_build ~= true then
    return;
  end
  local buffer         = vim.api.nvim_win_get_buf(window);
  local summary, group = summary(list.items or {});
  style.WindowSetStyles(window, {
    cursorline   = true;
    winfixheight = true;
  });
  style.WindowSetWinbar(
    window,
    "Build results · " .. (context.name or "Build"),
    summary,
    group
  );

  base.Map(
    "<Esc>",
    MODULE.Close,
    "Close build results",
    buffer
  );
  base.Map(
    "<C-c>",
    MODULE.Close,
    "Close build results",
    buffer
  );
end

local function close()
  vim.cmd("silent! cclose");
end

local function open_current()
  local list    = vim.fn.getqflist({ size = 0; context = 0; });
  local context = list.context or {};

  if context.rnoba_build ~= true or list.size == 0 then
    base.LogWarn("No build results available.");
    return;
  end

  local parent_window = vim.api.nvim_get_current_win();
  vim.cmd("botright copen");
  configure(vim.api.nvim_get_current_win());

  vim.api.nvim_set_current_win(parent_window);
end

local function open(items, options)
  items   = items   or {};
  options = options or {};

  vim.fn.setqflist({}, " ", {
    title = "Build · " .. (options.name or "Build");
    items = items;
    context = {
      rnoba_build = true;
      name        = options.name or "Build";
      root        = options.root;
    };
    quickfixtextfunc = "v:lua.RnobaBuildQuickfixText";
  });

  open_current();
end

local function clear()
  close();
  vim.fn.setqflist({}, " ", {
    title = "Build";
    items = {};
    context = {
      rnoba_build = true;
    };
    quickfixtextfunc = "v:lua.RnobaBuildQuickfixText";
  });
end


_G.RnobaBuildQuickfixText = function(info) return text(info); end

function MODULE.Open(items, options) open(items, options); end
function MODULE.Clear()              clear();              end
function MODULE.Close()              close();              end

return MODULE;
