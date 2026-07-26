vim.g.mapleader = ",";
vim.g.maplocalleader = ",";
vim.g.have_nerd_font = true;

vim.opt.tabstop = 2;
vim.opt.softtabstop = 2;
vim.opt.shiftwidth = 2;
vim.opt.expandtab = true;
vim.opt.relativenumber = true;
vim.opt.colorcolumn = "0";
vim.opt.wrap = false;
vim.opt.backup = false;
vim.opt.writebackup = false;
vim.opt.swapfile = false;
vim.opt.undofile = true;
vim.opt.updatetime = 250;
vim.opt.timeoutlen = 300;
vim.opt.clipboard = "unnamed";
vim.opt.cinoptions:append("l1,t0");
vim.opt.completeopt = "menu,menuone,noinsert";
vim.opt.termguicolors = true;

vim.o.mouse = "a";
vim.o.showmode = false;
vim.o.breakindent = true;
vim.o.splitright = true;
vim.o.splitbelow = true;
vim.o.inccommand = "split";
vim.o.scrolloff = 10;
vim.o.cmdheight = 0;
vim.o.showcmd = false;
vim.o.ruler = false;
vim.o.laststatus = 3;
vim.o.statusline = "%=";
vim.opt.fillchars = { eob = " " };

vim.g.netrw_sort_sequence = [[[\/]$,\<core\%(\.\d\+\)\=,\.[a-np-z]$,\.cpp$,*,\.o$,\.obj$,\.info$,\.swp$,\.bak$,\~$]];
vim.g.netrw_sort_by = "name";

_G.base = require("base");

base.Map(
  "<leader>y",
  '"+y',
  "Yank to system clipboard",
  nil,
  "v"
);
base.Map(
  "<Esc>",
  "<cmd>nohlsearch<CR>"
);
base.Map(
  "<C-h>",
  "<C-w><C-h>",
  "Move focus to the left window"
);
base.Map(
  "<C-l>",
  "<C-w><C-l>",
  "Move focus to the right window"
);
base.Map(
  "<C-j>",
  "<C-w><C-j>",
  "Move focus to the lower window"
);
base.Map(
  "<C-k>",
  "<C-w><C-k>",
  "Move focus to the upper window"
);
base.Map(
  "<C-f>",
  "<cmd>silent !tmux neww tmux-sessionizer<CR>"
);

vim.cmd("syntax enable");
vim.cmd.colorscheme("warm");

require("plugins");
require("build");
