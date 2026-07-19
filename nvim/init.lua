_G.system = require("system");
system.Map(
  "<leader>y",
  '"+y',
  "Yank",
  nil,
  "v"
);
system.Map(
  "<Esc><Esc>",
  "<C-\\><C-n>",
  "Exit terminal mode",
  nil,
  "t"
);
system.Map(
  "<Esc>",
  "<cmd>nohlsearch<CR>"
);
system.Map(
  "<C-h>",
  "<C-w><C-h>",
  "Move focus to the left window"
);
system.Map(
  "<C-l>",
  "<C-w><C-l>",
  "Move focus to the right window"
);
system.Map(
  "<C-j>",
  "<C-w><C-j>",
  "Move focus to the lower window"
);
system.Map(
  "<C-k>",
  "<C-w><C-k>",
  "Move focus to the upper window"
);
system.Map(
  "<C-f>",
  "<cmd>silent !tmux neww tmux-sessionizer<CR>"
);


vim.g.mapleader = ",";
vim.g.maplocalleader = ",";
vim.g.have_nerd_font = true;
vim.opt.tabstop = 2;
vim.opt.softtabstop = 2;
vim.opt.shiftwidth = 2;
vim.opt.expandtab = true;
vim.opt.relativenumber = true;
vim.opt.colorcolumn = "100";
vim.o.mouse = "a";
vim.o.showmode = false;
vim.g.netrw_sort_sequence = [[[\/]$,\<core\%(\.\d\+\)\=,\.[a-np-z]$,\.cpp$,*,\.o$,\.obj$,\.info$,\.swp$,\.bak$,\~$]];
vim.g.netrw_sort_by = "name";
vim.opt.wrap = false;
vim.opt.backup = false;
vim.opt.laststatus = 2;
vim.opt.writebackup = false;
vim.opt.swapfile = false;
vim.o.breakindent = true;
vim.o.undofile = true;
vim.o.updatetime = 250;
vim.o.timeoutlen = 300;
vim.o.splitright = true;
vim.o.splitbelow = true;
vim.o.inccommand = "split";
vim.o.scrolloff = 10;
vim.opt.clipboard = "unnamed";
vim.opt.cinoptions:append("l1,t0");
vim.opt.completeopt = "menu,menuone,noinsert";

require("build");
require("plugins/init");

vim.cmd.colorscheme("warm");
