local fzf = require("fzf-lua");

fzf.setup({
  files = {
    multiprocess = false,
  },
});

system.Map(
  "<leader>sh",
  fzf.helptags,
  "[S]earch [H]elp"
);
system.Map(
  "<leader>sk",
  fzf.keymaps,
  "[S]earch [K]eymaps"
);
system.Map(
  "<leader>sf",
  fzf.files,
  "[S]earch [F]iles"
);
system.Map(
  "<leader>ss",
  fzf.builtin,
  "[S]earch [S]elect FzfLua"
);
system.Map(
  "<leader>sw",
  fzf.grep_cword,
  "[S]earch current [W]ord"
);
system.Map(
  "<leader>sg",
  fzf.live_grep,
  "[S]earch by [G]rep"
);
system.Map(
  "<leader>sd",
  fzf.diagnostics_workspace,
  "[S]earch [D]iagnostics"
);
system.Map(
  "<leader>sr",
  fzf.resume,
  "[S]earch [R]esume"
);
system.Map(
  "<leader>s.",
  fzf.oldfiles,
  "[S]earch Recent Files ('.' for repeat)"
);
system.Map(
  "<leader><leader>",
  fzf.buffers,
  "Find existing buffers"
);

system.Map(
  "<leader>/",
  function()
    fzf.blines({
      previewer = false,
      winopts = {
        height   = 0.40,
        width    = 0.60,
        row      = 0.30,
        backdrop = 100,
      },
    });
  end,
  "[/] Fuzzily search in current buffer"
);

local function live_grep_open_files()
  local paths = {};
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
      local path = vim.api.nvim_buf_get_name(bufnr);

      if path ~= "" and vim.fn.filereadable(path) == 1 then
        paths[#paths + 1] = path;
      end
    end
  end

  if #paths == 0 then
    vim.notify("No open file buffers", vim.log.levels.INFO);
    return;
  end

  fzf.live_grep({
    search_paths = paths,
    prompt       = "Live Grep in Open Files> ",
  });
end

system.Map(
  "<leader>s/",
  live_grep_open_files,
  "[S]earch [/] in Open Files"
);

system.Map(
  "<leader>sn",
  function()
    fzf.files({ cwd = vim.fn.stdpath("config") });
  end,
  "[S]earch [N]eovim files"
);
