vim.pack.add({
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/folke/trouble.nvim",
  "https://github.com/mbbill/undotree",
});

vim.api.nvim_create_user_command("PackList", function()
  --TODO(rnoba): format this
  vim.print(vim.pack.get());
end, {});

vim.api.nvim_create_user_command("PackRemove", function(opts)
  local plugins = opts.fargs;
  if #plugins == 0 then
    vim.notify('Usage: :Uninstall plugin1 [plugin2 ...]', vim.log.levels.ERROR);
    return;
  end

  vim.ui.select(plugins, {
    prompt = 'Confirm uninstall?',
    format_item = function(item) return 'Remove: ' .. item; end,
  }, function(choice)
    if not choice then return end;
    local ok, err = pcall(vim.pack.del, plugins);
    if ok then
      vim.notify('Uninstalled: ' .. table.concat(plugins, ', '), vim.log.levels.INFO);
      vim.cmd('redraw');
      vim.notify('→ Run :restart to finish', vim.log.levels.WARN);
    else
      vim.notify('Error: ' .. tostring(err), vim.log.levels.ERROR);
    end
  end)
end,
{
  nargs = '+',
  desc = 'Uninstall one or more vim.pack plugins',
});

require("plugins/fzf");
require("plugins/trouble");
require("plugins/undotree");
require("plugins/gitsigns");
