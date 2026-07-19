if vim.g.colors_name then
  vim.cmd("highlight clear")
end

vim.g.colors_name = "warm"

local hl = vim.api.nvim_set_hl

local c = {
  black       = "#020202",
  dark        = "#0C0C0C",
  gray0       = "#1E1E1E",
  gray1       = "#222425",
  gray2       = "#303040",
  gray3       = "#362e25",
  gray4       = "#404040",
  gray5       = "#494949",
  gray6       = "#666666",

  orange      = "#fcaa05",
  orange_dim  = "#de8150",
  amber       = "#b99468",
  yellow      = "#f0c674",
  gold        = "#ffa900",
  red         = "#FF0000",
  red_dark    = "#db2828",
  green       = "#2ab34f",
  green_dim   = "#1be094",
  cyan        = "#00EE00",
  purple      = "#ba60c4",
  pink        = "#FF44DD",
  magenta     = "#de2368",

  bg          = "#020202",
  bg_alt      = "#100202",
  bg_float    = "#0C0C0C",
  fg          = "#b99468",
  comment     = "#666666",
  cursor      = "#00EE00",
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Base
-- ──────────────────────────────────────────────────────────────────────────────

hl(0, "Normal",          { fg = c.fg, bg = c.bg })
hl(0, "NormalFloat",     { fg = c.fg, bg = c.bg_float })
hl(0, "NormalNC",        { fg = c.fg, bg = c.bg })

hl(0, "Comment",         { fg = c.comment, italic = true })
hl(0, "Constant",        { fg = c.gold })
hl(0, "String",          { fg = c.gold })
hl(0, "Character",       { fg = c.gold })
hl(0, "Number",          { fg = c.gold })
hl(0, "Boolean",         { fg = c.gold })
hl(0, "Float",           { fg = c.gold })

hl(0, "Identifier",      { fg = c.amber })
hl(0, "Function",        { fg = c.orange })

hl(0, "Statement",       { fg = c.yellow })
hl(0, "Conditional",     { fg = c.yellow })
hl(0, "Repeat",          { fg = c.yellow })
hl(0, "Label",           { fg = c.yellow })
hl(0, "Operator",        { fg = "#bd2d2d" })
hl(0, "Keyword",         { fg = c.yellow })
hl(0, "Exception",       { fg = c.yellow })

hl(0, "PreProc",         { fg = "#dc7575" })
hl(0, "Include",         { fg = c.gold })
hl(0, "Define",          { fg = "#dc7575" })
hl(0, "Macro",           { fg = "#2895c7" })

hl(0, "Type",            { fg = "#edb211" })
hl(0, "StorageClass",    { fg = "#a7eb13" })
hl(0, "Structure",       { fg = "#de451f" })
hl(0, "Typedef",         { fg = "#de451f" })

hl(0, "Special",         { fg = c.red })
hl(0, "SpecialChar",     { fg = c.red })
hl(0, "Delimiter",       { fg = c.amber })
hl(0, "SpecialComment",  { fg = c.green })
hl(0, "Debug",           { fg = c.red })

hl(0, "Underlined",      { fg = c.pink, underline = true })
hl(0, "Ignore",          { fg = c.bg })
hl(0, "Error",           { fg = c.red, bg = "#3A0000" })
hl(0, "Todo",            { fg = "#ffae00", bg = "#362e25", bold = true })

-- ──────────────────────────────────────────────────────────────────────────────
-- UI
-- ──────────────────────────────────────────────────────────────────────────────

hl(0, "ColorColumn",     { bg = "#101010" })
hl(0, "Cursor",          { fg = c.bg, bg = c.cursor })
hl(0, "lCursor",         { fg = c.bg, bg = c.cursor })
hl(0, "CursorLine",      { bg = c.gray0 })
hl(0, "CursorColumn",    { bg = c.gray0 })
hl(0, "CursorLineNr",    { fg = "#efaf2f", bold = true })

hl(0, "LineNr",          { fg = c.gray4 })
hl(0, "LineNrAbove",     { fg = "#303040" })
hl(0, "LineNrBelow",     { fg = "#303040" })

hl(0, "SignColumn",      { bg = c.bg })
hl(0, "FoldColumn",      { fg = c.gray4, bg = c.bg })
hl(0, "Folded",          { fg = c.comment, bg = "#0C0C0C" })

hl(0, "Pmenu",           { fg = c.fg, bg = "#222425" })
hl(0, "PmenuSel",        { fg = "#ffffff", bg = "#63523d" })
hl(0, "PmenuSbar",       { bg = "#222425" })
hl(0, "PmenuThumb",      { bg = "#b99468" })

hl(0, "StatusLine",      { fg = c.fg, bg = "#222425" })
hl(0, "StatusLineNC",    { fg = c.comment, bg = "#101010" })

hl(0, "TabLine",         { fg = c.comment, bg = "#101010" })
hl(0, "TabLineFill",     { bg = "#101010" })
hl(0, "TabLineSel",      { fg = c.orange, bg = "#362e25", bold = true })

hl(0, "Visual",          { bg = "#303040" })
hl(0, "VisualNOS",       { bg = "#303040" })

hl(0, "MatchParen",      { fg = "#8ffff2", bold = true, underline = true })

hl(0, "Directory",       { fg = c.orange })
hl(0, "Title",           { fg = c.orange, bold = true })
hl(0, "Question",        { fg = c.green })
hl(0, "MoreMsg",         { fg = c.green })
hl(0, "ModeMsg",         { fg = c.orange })
hl(0, "WarningMsg",      { fg = "#f0500c" })
hl(0, "ErrorMsg",        { fg = "#ffffff", bg = c.red_dark })

hl(0, "DiffAdd",         { bg = "#1a3d1a" })
hl(0, "DiffChange",      { bg = "#3a2e1a" })
hl(0, "DiffDelete",      { fg = c.red, bg = "#3A0000" })
hl(0, "DiffText",        { bg = "#5a3f1a" })

hl(0, "@variable",               { fg = c.amber })
hl(0, "@variable.builtin",       { fg = "#de451f" })
hl(0, "@variable.parameter",     { fg = "#de8150" })

hl(0, "@function",               { fg = c.orange })
hl(0, "@function.builtin",       { fg = "#de451f" })
hl(0, "@function.call",          { fg = c.orange })
hl(0, "@function.method",        { fg = c.orange })
hl(0, "@method",                 { link = "@function.method" })

hl(0, "@keyword",                { fg = c.yellow })
hl(0, "@keyword.function",       { fg = c.yellow })
hl(0, "@keyword.operator",       { fg = "#bd2d2d" })
hl(0, "@keyword.return",         { fg = "#f0500c" })

hl(0, "@string",                 { fg = c.gold })
hl(0, "@string.escape",          { fg = c.red })
hl(0, "@string.special",         { fg = "#2895c7" })

hl(0, "@number",                 { fg = c.gold })
hl(0, "@boolean",                { fg = c.gold })

hl(0, "@type",                   { fg = "#edb211" })
hl(0, "@type.builtin",           { fg = "#a7eb13" })
hl(0, "@type.definition",        { fg = "#de451f" })

hl(0, "@constant",               { fg = c.gold })
hl(0, "@constant.builtin",       { fg = "#6eb535" })
hl(0, "@constant.macro",         { fg = "#2895c7" })

hl(0, "@comment",                { fg = c.comment, italic = true })
hl(0, "@comment.documentation",  { fg = "#2ab34f", italic = true })
hl(0, "@tag",                    { fg = "#c9598a" })

hl(0, "@punctuation.bracket",    { fg = "#809ba2" })
hl(0, "@punctuation.delimiter",  { fg = c.amber })

-- hl(0, "TelescopeNormal",        { bg = "#0C0C0C" })
-- hl(0, "TelescopeBorder",        { fg = "#63523d", bg = "#0C0C0C" })
-- hl(0, "@markup.heading",        { fg = c.orange, bold = true })
