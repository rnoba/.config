local styles = require("ui.styles");

local MODULE = {};

local function close()
  vim.cmd("silent! cclose");
end

local function configure(window)
  if not vim.api.nvim_win_is_valid(window) then
    return;
  end

  local buffer = vim.api.nvim_win_get_buf(window);
  if vim.bo[buffer].buftype ~= "quickfix" then
    return;
  end

  local list  = vim.fn.getqflist({ size = 0; });
  local title = vim.w[window].quickfix_title or "Quickfix";
  local count = tonumber(list.size) or 0;

  styles.ApplyPanel(window, {
    cursorline   = true;
    winfixheight = true;
  });

  styles.SetPanelWinbar(
    window,
    title,
    string.format("%d item%s", count, count == 1 and "" or "s")
  );
  system.Map(
    "<Esc>",
    close,
    "Close quickfix window",
    buffer
  );
  system.Map(
    "<C-c>",
    close,
    "Close quickfix window",
    buffer
  );
end

function MODULE.Setup()
  vim.api.nvim_create_autocmd("FileType", {
    group   = vim.api.nvim_create_augroup("rnoba-quickfix-window", { clear = true; });
    pattern = "qf";
    callback = function()
      configure(vim.api.nvim_get_current_win());
    end;
  });
end

return MODULE;
