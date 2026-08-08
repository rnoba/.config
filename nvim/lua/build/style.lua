local _MODULE = {};

local PANEL_HIGHLIGHTS = table.concat({
  "Normal:RnobaPanelNormal";
  "NormalNC:RnobaPanelNormalNC";
  "EndOfBuffer:RnobaPanelEndOfBuffer";
  "CursorLine:RnobaPanelCursorLine";
  "QuickFixLine:RnobaPanelCursorLine";
  "WinSeparator:RnobaPanelSeparator";
}, ",");

local function statusline_escape(value)
  return tostring(value):gsub("%%", "%%%%");
end

function _MODULE.Window(window, options)
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
  vim.wo[window].winfixbuf      = true;
  vim.wo[window].statusline     = "";
  vim.wo[window].winhighlight   = PANEL_HIGHLIGHTS;
end

function _MODULE.Winbar(window, title, right, right_highlight)
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
  vim.wo[window].winbar = table.concat(parts);
end

return _MODULE;
