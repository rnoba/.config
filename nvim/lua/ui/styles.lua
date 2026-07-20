local MODULE = {};

local function highlight(name)
  local ok, value = pcall(vim.api.nvim_get_hl, 0, {
    name = name;
    link = false;
  });

  return ok and value or {};
end

local function set_highlight(name, value)
  vim.api.nvim_set_hl(0, name, value);
end

local function statusline_escape(value)
  return tostring(value):gsub("%%", "%%%%");
end

function MODULE.Setup()
  local normal       = highlight("Normal");
  local normal_nc    = highlight("NormalNC");
  local normal_float = highlight("NormalFloat");
  local cursor_line  = highlight("CursorLine");
  local winbar       = highlight("WinBar");
  local winbar_nc    = highlight("WinBarNC");
  local comment      = highlight("Comment");
  local separator    = highlight("WinSeparator");
  local success      = highlight("DiagnosticOk");
  local warning      = highlight("DiagnosticWarn");
  local failure      = highlight("DiagnosticError");

  local background        = normal.bg;
  local winbar_background = winbar.bg or cursor_line.bg or background;

  set_highlight("RnobaPanelNormal", {
    fg = normal.fg;
    bg = background;
  });

  set_highlight("RnobaPanelNormalNC", {
    fg = normal.fg;
    bg = background;
  });

  set_highlight("RnobaPanelEndOfBuffer", {
    fg = background;
    bg = background;
  });

  set_highlight("RnobaPanelCursorLine", {
    fg = cursor_line.fg or normal.fg;
    bg = cursor_line.bg or background;
  });

  set_highlight("RnobaPanelSeparator", {
    fg = normal.fg;
    bg = background;
  });

  set_highlight("RnobaPanelWinBar", {
    fg   = normal.fg;
    bg   = background;
    bold = true;
  });

  set_highlight("RnobaPanelMuted", {
    fg = comment.fg or winbar_nc.fg or normal_nc.fg;
    bg = background;
  });

  set_highlight("RnobaPanelSuccess", {
    fg   = success.fg or normal.fg;
    bg   = background;
    bold = true;
  });

  set_highlight("RnobaPanelWarn", {
    fg   = warning.fg or normal.fg;
    bg   = background;
    bold = true;
  });

  set_highlight("RnobaPanelError", {
    fg   = failure.fg or normal.fg;
    bg   = background;
    bold = true;
  });
end

function MODULE.ApplyPanel(window, options)
  options = options or {};

  vim.wo[window].number         = false;
  vim.wo[window].relativenumber = false;
  vim.wo[window].signcolumn     = "no";
  vim.wo[window].foldcolumn     = "0";
  vim.wo[window].statuscolumn   = "";
  vim.wo[window].colorcolumn    = "";
  vim.wo[window].cursorline     = options.cursorline == true;
  vim.wo[window].cursorcolumn   = false;
  vim.wo[window].list           = false;
  vim.wo[window].wrap           = options.wrap == true;
  vim.wo[window].spell          = false;
  vim.wo[window].winfixheight   = options.winfixheight ~= false;
  vim.wo[window].statusline     = "";

  vim.wo[window].winhighlight = table.concat({
    "Normal:RnobaPanelNormal";
    "NormalNC:RnobaPanelNormalNC";
    "EndOfBuffer:RnobaPanelEndOfBuffer";
    "CursorLine:RnobaPanelCursorLine";
    "QuickFixLine:RnobaPanelCursorLine";
    "WinSeparator:RnobaPanelSeparator";
  }, ",");
end

function MODULE.SetPanelWinbar(window, title, right, right_highlight)
  local parts = {
    "%#RnobaPanelWinBar#";
    statusline_escape(title);
    "%=";
  };

  if right and right ~= "" then
    parts[#parts + 1] = "%#" .. (right_highlight or "RnobaPanelMuted") .. "#";
    parts[#parts + 1] = statusline_escape(right);
    parts[#parts + 1] = "  ";
  end

  parts[#parts + 1] = "%*";

  vim.w[window].rnoba_winbar_owner = "panel";
  vim.wo[window].winbar = table.concat(parts);
end

function MODULE.FileWinbar()
  return table.concat({
    "%#WinBar# ";
    "%f";
    " %m";
    "%r";
    "%=";
    "%l:%c";
    "  %P ";
  });
end

return MODULE;
