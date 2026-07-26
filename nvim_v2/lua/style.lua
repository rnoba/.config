local MODULE = {};

local function statusline_escape(value)
  return tostring(value):gsub("%%", "%%%%");
end

function MODULE.WindowSetStyles(window, options)
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

  vim.wo[window].winhighlight = table.concat({
    "Normal:RnobaPanelNormal";
    "NormalNC:RnobaPanelNormalNC";
    "EndOfBuffer:RnobaPanelEndOfBuffer";
    "CursorLine:RnobaPanelCursorLine";
    "QuickFixLine:RnobaPanelCursorLine";
    "WinSeparator:RnobaPanelSeparator";
  }, ",");
end

function MODULE.WindowSetWinbar(window, title, right, right_highlight)
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
