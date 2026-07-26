local base = require("base");
local fzf  = require("fzf-lua");

fzf.setup({
  files = {
    multiprocess = false;
  };
});

fzf.register_ui_select();

base.Map(
  "<leader>sk",
  fzf.keymaps,
  "[S]earch [K]eymaps"
);
base.Map(
  "<leader>sf",
  fzf.files,
  "[S]earch [F]iles"
);
base.Map(
  "<leader>ss",
  fzf.builtin,
  "[S]earch [S]elect FzfLua"
);
base.Map(
  "<leader>sw",
  fzf.grep_cword,
  "[S]earch current [W]ord"
);
base.Map(
  "<leader>sg",
  fzf.live_grep,
  "[S]earch by [G]rep"
);
base.Map(
  "<leader>sd",
  fzf.diagnostics_workspace,
  "[S]earch [D]iagnostics"
);
base.Map(
  "<leader>sr",
  fzf.resume,
  "[S]earch [R]esume"
);
base.Map(
  "<leader><leader>",
  fzf.buffers,
  "Find existing buffers"
);
base.Map(
  "<leader>sn",
  function()
    fzf.files({ cwd = vim.fn.stdpath("config") });
  end,
  "[S]earch [N]eovim files"
);
