local styles = require("ui.styles");

local MODULE = {};

local OUTPUT_NAMESPACE = vim.api.nvim_create_namespace("rnoba-build-output");

local owner_buffer = nil;
local owner_window = nil;
local closing_owner = false;

local output_buffer = nil;
local output_window = nil;
local output_lines  = {};

local output_info   = {
  name   = "Build";
  status = "output";
  group  = "RnobaPanelMuted";
};


local function close_output()
  if output_window and vim.api.nvim_win_is_valid(output_window) then
    vim.api.nvim_win_close(output_window, true);
  end

  output_window = nil;
end

local function close_results()
  vim.cmd("silent! cclose");
end

local function close_owned_panels()
  if closing_owner then
    return;
  end

  closing_owner = true;

  close_output();
  close_results();

  owner_buffer = nil;
  owner_window = nil;
  closing_owner = false;
end

local function owner_is_open()
  return owner_buffer
  and owner_window
  and vim.api.nvim_buf_is_valid(owner_buffer)
  and vim.api.nvim_win_is_valid(owner_window)
  and vim.api.nvim_win_get_buf(owner_window) == owner_buffer;
end

local function panel_height(line_count)
  local maximum = math.max(6, math.floor(vim.o.lines * 0.35));
  return math.min(math.max(line_count, 3), maximum);
end

local function resize(window, height)
  vim.api.nvim_win_call(window, function()
    vim.cmd("resize " .. height);
  end);
end

local function set_output_highlights(buffer, lines)
  vim.api.nvim_buf_clear_namespace(buffer, OUTPUT_NAMESPACE, 0, -1);

  for index, line in ipairs(lines) do
    local highlight = nil;
    local lower     = line:lower();

    if lower:find("fatal error:", 1, true) or lower:find("error:", 1, true) then
      highlight = "DiagnosticError";
    elseif lower:find("warning:", 1, true) then
      highlight = "DiagnosticWarn";
    elseif lower:find("note:", 1, true) then
      highlight = "DiagnosticInfo";
    end

    if highlight then
      vim.api.nvim_buf_add_highlight(
        buffer,
        OUTPUT_NAMESPACE,
        highlight,
        index - 1,
        0,
        -1
      );
    end
  end
end

local function create_output_buffer()
  local buffer = vim.api.nvim_create_buf(false, true);

  vim.api.nvim_buf_set_name(buffer, "[Build Output]");

  vim.bo[buffer].buftype    = "nofile";
  vim.bo[buffer].bufhidden  = "wipe";
  vim.bo[buffer].buflisted  = false;
  vim.bo[buffer].swapfile   = false;
  vim.bo[buffer].filetype   = "buildoutput";

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buffer;
    once   = true;
    callback = function()
      output_buffer = nil;
      output_window = nil;
    end;
  });

  return buffer;
end

local function configure_output(window, buffer)
  styles.ApplyPanel(window, {
    cursorline   = false;
    winfixheight = true;
  });

  local line_count = #output_lines;
  local summary    = string.format(
    "%s · %d line%s",
    output_info.status,
    line_count,
    line_count == 1 and "" or "s"
  );

  styles.SetPanelWinbar(
    window,
    "Build output · " .. output_info.name,
    summary,
    output_info.group
  );

  system.Map(
    "q",
    close_output,
    "Close build output",
    buffer
  );
  system.Map(
    "<Esc>",
    close_output,
    "Close build output",
    buffer
  );
  system.Map(
    "<C-c>",
    close_output,
    "Close build output",
    buffer
  );
end

local function open_output(options)
  if not owner_is_open() then
    return;
  end

  options = options or {
    allow_empty = true;
  };


  if #output_lines == 0 and options.allow_empty ~= true then
    system.LogWarn("No build output available.");
    return;
  end

  local lines = output_lines;
  if #lines == 0 then
    lines = { "No standard output."; };
  end

  local previous_window = vim.api.nvim_get_current_win();

  if not output_buffer or not vim.api.nvim_buf_is_valid(output_buffer) then
    output_buffer = create_output_buffer();
  end

  if not output_window or not vim.api.nvim_win_is_valid(output_window) then
    vim.cmd("botright split");
    output_window = vim.api.nvim_get_current_win();
    vim.api.nvim_win_set_buf(output_window, output_buffer);
  end

  vim.bo[output_buffer].modifiable = true;
  vim.bo[output_buffer].readonly   = false;
  vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, lines);
  vim.bo[output_buffer].modifiable = false;
  vim.bo[output_buffer].readonly   = true;

  set_output_highlights(output_buffer, lines);
  configure_output(output_window, output_buffer);
  resize(output_window, panel_height(#lines));

  if options.focus == true then
    vim.api.nvim_set_current_win(output_window);
  elseif vim.api.nvim_win_is_valid(previous_window) then
    vim.api.nvim_set_current_win(previous_window);
  end

end

local function toggle_output()
  if output_window and vim.api.nvim_win_is_valid(output_window) then
    close_output();
    return;
  end

  open_output();
end

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

local function quickfix_text(info)
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
      local prefix = " " .. item_type(item) .. "  ";

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

local function clear_matches(window)
  local matches = vim.w[window].rnoba_build_matches or {};

  vim.api.nvim_win_call(window, function()
    for _, id in ipairs(matches) do
      pcall(vim.fn.matchdelete, id);
    end
  end);

  vim.w[window].rnoba_build_matches = {};
end

local function configure_result_matches(window)
  clear_matches(window);

  local matches = {};
  vim.api.nvim_win_call(window, function()
    matches[#matches + 1] = vim.fn.matchadd("DiagnosticError", [[^ E  ]]);
    matches[#matches + 1] = vim.fn.matchadd("DiagnosticWarn", [[^ W  ]]);
    matches[#matches + 1] = vim.fn.matchadd("DiagnosticInfo", [[^ I  ]]);
    matches[#matches + 1] = vim.fn.matchadd("Comment", [[│]]);
  end);

  vim.w[window].rnoba_build_matches = matches;
end

local function count_items(items)
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

  return counts;
end

local function count_label(count, singular, plural)
  if count == 0 then
    return nil;
  end

  return string.format("%d %s", count, count == 1 and singular or plural);
end

local function result_summary(items)
  local counts = count_items(items);
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

local function configure_results(window)
  if not vim.api.nvim_win_is_valid(window) then
    return;
  end

  local list = vim.fn.getqflist({
    items   = 0;
    context = 0;
    size    = 0;
  });

  local context = list.context or {};
  if context.rnoba_build ~= true then
    return;
  end

  local buffer = vim.api.nvim_win_get_buf(window);
  local summary, group = result_summary(list.items or {});

  styles.ApplyPanel(window, {
    cursorline   = true;
    winfixheight = true;
  });

  styles.SetPanelWinbar(
    window,
    "Build results · " .. (context.name or "Build"),
    summary,
    group
  );

  configure_result_matches(window);

  system.Map(
    "<Esc>",
    close_results,
    "Close build results",
    buffer
  );
  system.Map(
    "<C-c>",
    close_results,
    "Close build results",
    buffer
  );
  system.Map(
    "o",
    toggle_output,
    "Toggle raw build output",
    buffer
  );
end

local function open_current_results()
  if not owner_is_open() then
    return;
  end

  local list    = vim.fn.getqflist({ size = 0; context = 0; });
  local context = list.context or {};

  if context.rnoba_build ~= true or list.size == 0 then
    system.LogWarn("No build results available.");
    return;
  end

  local parent_window = vim.api.nvim_get_current_win();
  vim.cmd("botright copen " .. panel_height(list.size));
  configure_results(vim.api.nvim_get_current_win());

  vim.api.nvim_set_current_win(parent_window);
end

function MODULE.RecordOutput(lines, options)
  options = options or {};

  output_lines = vim.deepcopy(lines or {});
  output_info = {
    name   = options.name or "Build";
    status = options.status or "output";
    group  = options.group or "RnobaPanelMuted";
  };

  if output_window and vim.api.nvim_win_is_valid(output_window) then
    open_output();
  end
end

function MODULE.OpenOutput(options)
  open_output(options);
end

function MODULE.OpenResults(items, options)
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

  open_current_results();
end

function MODULE.ClearResults()
  close_results();

  vim.fn.setqflist({}, " ", {
    title = "Build";
    items = {};
    context = {
      rnoba_build = true;
    };
    quickfixtextfunc = "v:lua.RnobaBuildQuickfixText";
  });
end

function MODULE.Reset()
  close_output();

  MODULE.ClearResults();
  output_lines = {};
end

local owner_group = vim.api.nvim_create_augroup("rnoba-build-owner", {
  clear = true;
});

vim.api.nvim_create_autocmd("QuitPre", {
  group    = owner_group;
  callback = function()
    if owner_window ~= vim.api.nvim_get_current_win() then
      return;
    end

    close_owned_panels();
  end;
});

vim.api.nvim_create_autocmd({
  "BufDelete";
  "BufWipeout";
}, {
  group    = owner_group;
  callback = function(event)
    if event.buf ~= owner_buffer then
      return;
    end

    close_owned_panels();
  end;
});

_G.RnobaBuildQuickfixText = function(info)
  return quickfix_text(info);
end

vim.api.nvim_create_user_command("BuildOutput", function()
  toggle_output();
end,
{
  desc = "Toggle the latest raw build output.";
});

vim.api.nvim_create_user_command("BuildResults", function()
  open_current_results();
end,
{
  desc = "Open the latest build results.";
});

vim.api.nvim_create_autocmd("FileType", {
  group   = vim.api.nvim_create_augroup("rnoba-build-results-window", { clear = true; });
  pattern = "qf";
  callback = function()
    configure_results(vim.api.nvim_get_current_win());
  end;
});

function MODULE.SetOwner(buffer, window)
  owner_buffer = buffer;
  owner_window = window;
end

return MODULE;
