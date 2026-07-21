local styles   = require("ui.styles");
local winbar   = require("ui.winbar");
local quickfix = require("ui.quickfix");

local MODULE = {};

function MODULE.Setup()
  styles.Setup();
  winbar.Setup();
  quickfix.Setup();

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("rnoba-ui-highlights", { clear = true; });
    callback = function()
      styles.Setup();
    end;
  });
end

return MODULE;
