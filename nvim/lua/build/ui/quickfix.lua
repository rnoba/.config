local MODULE = {};

local function relative_path(root, path)
  if path == "" then
    return "";
  end

  path = vim.fs.normalize(path);
  root = root and vim.fs.normalize(root) or nil;

  if root and path:sub(1, #root) == root then
    local separator = path:sub(#root + 1, #root + 1);
    if separator == "/" or separator == "\\" then
      return path:sub(#root + 2);
    end
  end

  return vim.fn.fnamemodify(path, ":~");
end

local function item_location(item, root)
  local path = "";

  if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
    path = vim.api.nvim_buf_get_name(item.bufnr);
  end

  path = relative_path(root, path);

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

local function item_type(item)
  local kind = tostring(item.type or ""):upper():sub(1, 1);
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

function MODULE.Text(info)
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
    local location = item_location(item, context.root);
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
      local prefix   = " " .. item_type(item) .. "  ";

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

function MODULE.Summary(items)
  local counts = {
    error   = 0;
    warning = 0;
    info    = 0;
  };

  for _, item in ipairs(items) do
    local kind = item_type(item);

    if kind == "E" then
      counts.error = counts.error + 1;
    elseif kind == "W" then
      counts.warning = counts.warning + 1;
    else
      counts.info = counts.info + 1;
    end
  end

  local parts = {
    count_label(counts.error, "error", "errors");
    count_label(counts.warning, "warning", "warnings");
    count_label(counts.info, "note", "notes");
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

return MODULE;
