local styles = require("ui.styles");

local MODULE = {};

local function configure(window)
  if not vim.api.nvim_win_is_valid(window) then
    return;
  end

  local buffer = vim.api.nvim_win_get_buf(window);
  if vim.bo[buffer].buftype ~= "" then
    if vim.w[window].rnoba_winbar_owner == "file" then
      vim.w[window].rnoba_winbar_owner = nil;
      vim.wo[window].winbar = "";
    end
    return;
  end

  vim.w[window].rnoba_winbar_owner = "file";
  vim.wo[window].winbar = styles.FileWinbar();
end

function MODULE.Setup()
  local group = vim.api.nvim_create_augroup("rnoba-winbar", {
    clear = true;
  });

  vim.api.nvim_create_autocmd({
    "VimEnter";
    "WinNew";
    "BufWinEnter";
  }, {
    group = group;
    callback = function()
      configure(vim.api.nvim_get_current_win());
    end;
  });
end

return MODULE;
