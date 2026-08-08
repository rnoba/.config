vim.cmd("highlight clear");

if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset");
end

vim.g.colors_name = "warm";

local function set_highlight(name, options)
  vim.api.nvim_set_hl(0, name, options);
end

local function get_highlight(name)
  local ok, value = pcall(vim.api.nvim_get_hl, 0, {
    name = name;
    link = false;
  });

  return ok and value or {};
end

local COLORS = {
  gray0    = "#1E1E1E";
  gray4    = "#404040";

  orange   = "#fcaa05";
  amber    = "#b99468";
  yellow   = "#f0c674";
  gold     = "#ffa900";
  red      = "#FF0000";
  red_dark = "#db2828";
  green    = "#2ab34f";
  pink     = "#FF44DD";

  bg       = "#0f0f10";
  bg_float = "#0C0C0C";
  fg       = "#b99468";
  comment  = "#666666";
  cursor   = "#00EE00";
};

set_highlight("Normal",      { fg = COLORS.fg, bg = COLORS.bg });
set_highlight("NormalFloat", { fg = COLORS.fg, bg = COLORS.bg_float });
set_highlight("NormalNC",    { fg = COLORS.fg, bg = COLORS.bg });

set_highlight("Comment",   { fg = COLORS.comment, italic = true });
set_highlight("Constant",  { fg = COLORS.gold });
set_highlight("String",    { fg = COLORS.gold });
set_highlight("Character", { fg = COLORS.gold });
set_highlight("Number",    { fg = COLORS.gold });
set_highlight("Boolean",   { fg = COLORS.gold });
set_highlight("Float",     { fg = COLORS.gold });

set_highlight("Identifier",  { fg = COLORS.amber });
set_highlight("Function",    { fg = COLORS.orange });
set_highlight("Statement",   { fg = COLORS.yellow });
set_highlight("Conditional", { fg = COLORS.yellow });
set_highlight("Repeat",      { fg = COLORS.yellow });
set_highlight("Label",       { fg = COLORS.yellow });
set_highlight("Operator",    { fg = "#bd2d2d" });
set_highlight("Keyword",     { fg = COLORS.yellow });
set_highlight("Exception",   { fg = COLORS.yellow });
set_highlight("PreProc",     { fg = "#dc7575" });
set_highlight("Include",     { fg = COLORS.gold });
set_highlight("Define",      { fg = "#dc7575" });
set_highlight("Macro",       { fg = "#2895c7" });

set_highlight("Type",           { fg = "#edb211" });
set_highlight("StorageClass",   { fg = "#a7eb13" });
set_highlight("Structure",      { fg = "#de451f" });
set_highlight("Typedef",        { fg = "#de451f" });
set_highlight("Special",        { fg = COLORS.red });
set_highlight("SpecialChar",    { fg = COLORS.red });
set_highlight("Delimiter",      { fg = COLORS.amber });
set_highlight("SpecialComment", { fg = COLORS.green });
set_highlight("Debug",          { fg = COLORS.red });
set_highlight("Underlined",     { fg = COLORS.pink, underline = true });
set_highlight("Ignore",         { fg = COLORS.bg });
set_highlight("Error",          { fg = COLORS.red, bg = "#3A0000" });
set_highlight("Todo",           { fg = "#ffae00", bg = "#362e25", bold = true });

set_highlight("ColorColumn",  { bg = "#101010" });
set_highlight("Cursor",       { fg = COLORS.bg, bg = COLORS.cursor });
set_highlight("lCursor",      { fg = COLORS.bg, bg = COLORS.cursor });
set_highlight("CursorLine",   { bg = COLORS.gray0 });
set_highlight("CursorColumn", { bg = COLORS.gray0 });
set_highlight("CursorLineNr", { fg = "#efaf2f", bold = true });
set_highlight("LineNr",       { fg = COLORS.gray4 });
set_highlight("LineNrAbove",  { fg = "#303040" });
set_highlight("LineNrBelow",  { fg = "#303040" });
set_highlight("SignColumn",   { bg = COLORS.bg });
set_highlight("FoldColumn",   { fg = COLORS.gray4, bg = COLORS.bg });
set_highlight("Folded",       { fg = COLORS.comment, bg = "#0C0C0C" });
set_highlight("Pmenu",        { fg = COLORS.fg, bg = "#222425" });
set_highlight("PmenuSel",     { fg = "#ffffff", bg = "#63523d" });
set_highlight("PmenuSbar",    { bg = "#222425" });
set_highlight("PmenuThumb",   { bg = "#b99468" });
set_highlight("StatusLine",   { fg = COLORS.fg,      bg = COLORS.bg });
set_highlight("StatusLineNC", { fg = COLORS.comment, bg = COLORS.bg });
set_highlight("TabLine",      { fg = COLORS.comment, bg = "#101010" });
set_highlight("TabLineFill",  { bg = "#101010" });
set_highlight("TabLineSel",   { fg = COLORS.orange, bg = "#362e25", bold = true });
set_highlight("Visual",       { bg = "#303040" });
set_highlight("VisualNOS",    { bg = "#303040" });
set_highlight("MatchParen",   { fg = "#8ffff2", bold = true, underline = true });
set_highlight("Directory",    { fg = COLORS.orange });
set_highlight("Title",        { fg = COLORS.orange, bold = true });
set_highlight("Question",     { fg = COLORS.green });
set_highlight("MoreMsg",      { fg = COLORS.green });
set_highlight("ModeMsg",      { fg = COLORS.orange });
set_highlight("WarningMsg",   { fg = "#f0500c" });
set_highlight("ErrorMsg",     { fg = "#ffffff", bg = COLORS.red_dark });
set_highlight("DiffAdd",      { bg = "#1a3d1a" });
set_highlight("DiffChange",   { bg = "#3a2e1a" });
set_highlight("DiffDelete",   { fg = COLORS.red, bg = "#3A0000" });
set_highlight("DiffText",     { bg = "#5a3f1a" });

set_highlight("@variable",           { fg = COLORS.amber });
set_highlight("@variable.builtin",   { fg = "#de451f" });
set_highlight("@variable.parameter", { fg = "#de8150" });
set_highlight("@function",           { fg = COLORS.orange });
set_highlight("@function.builtin",   { fg = "#de451f" });
set_highlight("@function.call",      { fg = COLORS.orange });
set_highlight("@function.method",    { fg = COLORS.orange });
set_highlight("@method",             { link = "@function.method" });
set_highlight("@keyword",            { fg = COLORS.yellow });
set_highlight("@keyword.function",   { fg = COLORS.yellow });
set_highlight("@keyword.operator",   { fg = "#bd2d2d" });
set_highlight("@keyword.return",     { fg = "#f0500c" });
set_highlight("@string",             { fg = COLORS.gold });
set_highlight("@string.escape",      { fg = COLORS.red });
set_highlight("@string.special",     { fg = "#2895c7" });
set_highlight("@number",             { fg = COLORS.gold });
set_highlight("@boolean",            { fg = COLORS.gold });
set_highlight("@type",               { fg = "#edb211" });
set_highlight("@type.builtin",       { fg = "#a7eb13" });
set_highlight("@type.definition",    { fg = "#de451f" });
set_highlight("@constant",           { fg = COLORS.gold });
set_highlight("@constant.builtin",   { fg = "#6eb535" });
set_highlight("@constant.macro",     { fg = "#2895c7" });

set_highlight("@comment",                { fg = COLORS.comment, italic = true });
set_highlight("@comment.documentation",  { fg = "#2ab34f", italic = true });
set_highlight("@tag",                    { fg = "#c9598a" });
set_highlight("@punctuation.bracket",    { fg = "#809ba2" });
set_highlight("@punctuation.delimiter",  { fg = COLORS.amber });

local normal      = get_highlight("Normal");
local normal_nc   = get_highlight("NormalNC");
local cursor_line = get_highlight("CursorLine");
local winbar_nc   = get_highlight("WinBarNC");
local comment     = get_highlight("Comment");
local success     = get_highlight("DiagnosticOk");
local warning     = get_highlight("DiagnosticWarn");
local failure     = get_highlight("DiagnosticError");
set_highlight("RnobaPanelNormal", {
  fg = normal.fg;
  bg = normal.bg;
});

set_highlight("RnobaPanelNormalNC", {
  fg = normal_nc.fg;
  bg = normal_nc.bg;
});

set_highlight("RnobaPanelEndOfBuffer", {
  fg = normal.bg;
  bg = normal.bg;
});

set_highlight("RnobaPanelCursorLine", {
  fg = cursor_line.fg or normal.fg;
  bg = cursor_line.bg or normal.bg;
});

set_highlight("RnobaPanelSeparator", {
  fg = normal.fg;
  bg = normal.bg;
});

set_highlight("RnobaPanelWinBar", {
  fg   = normal.fg;
  bg   = normal.bg;
  bold = true;
});

set_highlight("RnobaPanelMuted", {
  fg = comment.fg or winbar_nc.fg or normal_nc.fg;
  bg = normal.bg;
});

set_highlight("RnobaPanelSuccess", {
  fg   = success.fg or normal.fg;
  bg   = normal.bg;
  bold = true;
});

set_highlight("RnobaPanelWarn", {
  fg   = warning.fg or normal.fg;
  bg   = normal.bg;
  bold = true;
});

set_highlight("RnobaPanelError", {
  fg   = failure.fg or normal.fg;
  bg   = normal.bg;
  bold = true;
});
