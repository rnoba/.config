require("trouble").setup();

system.Map(
  "<leader>xa",
  "<cmd>Trouble diagnostics toggle<cr>",
  "Diagnostics (Trouble)"
);

system.Map(
  "<leader>xx",
  "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  "Buffer Diagnostics (Trouble)"
);

system.Map(
  "<leader>cs",
  "<cmd>Trouble symbols toggle focus=false<cr>",
  "Symbols (Trouble)"
);
