vim.pack.add({
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/mbbill/undotree",
});

vim.api.nvim_create_user_command("PackList", function()
  local lines = {};

  for _, plugin in ipairs(vim.pack.get(nil, { info = false })) do
    lines[#lines + 1] = string.format(
      "%-24s %s",
      plugin.spec.name,
      plugin.spec.src
    );
  end

  vim.api.nvim_echo({
    { table.concat(lines, "\n") },
  }, false, {});

end, {});

vim.api.nvim_create_user_command("PackRefresh", function(opts)
  local stale = {};

  for _, plugin in ipairs(vim.pack.get(nil, { info = false })) do
    if not plugin.active then
      stale[#stale + 1] = plugin.spec.name;
    end
  end

  table.sort(stale);
  if #stale == 0 then
    vim.notify("PackRefresh: no stale plugins found");
    return;
  end

  if not opts.bang then
    local prompt = string.format(
      "Remove %d stale plugin%s?\n\n%s",
      #stale,
      #stale == 1 and "" or "s",
      table.concat(stale, "\n")
    );

    if vim.fn.confirm(prompt, "&Remove\n&Cancel", 2) ~= 1 then
      return;
    end
  end

  local ok, err = pcall(vim.pack.del, stale);
  if not ok then
    system.LogError("PackRefresh failed:\n" .. tostring(err));
    return;
  end

  vim.notify(string.format(
    "PackRefresh: removed %d plugin%s:\n%s",
    #stale,
    #stale == 1 and "" or "s",
    table.concat(stale, "\n")
  ));
end,
{
  bang = true,
  desc = "Remove plugins not declared through vim.pack.add()",
});

vim.api.nvim_create_user_command("PackRemove", function(opts)
  local plugins = opts.fargs;
  if #plugins == 0 then
    system.LogError("Usage: :Uninstall plugin1 [plugin2 ...]");
    return;
  end

  vim.ui.select(plugins, {
    prompt = 'Confirm uninstall?',
    format_item = function(item) return 'Remove: ' .. item; end,
  }, function(choice)
    if not choice then return end;
    local ok, err = pcall(vim.pack.del, plugins);
    if ok then
      system.LogInfo("Uninstalled: " .. table.concat(plugins, ', '));
      vim.cmd('redraw');
      system.LogWarn("→ Run :restart to finish");
    else
      system.LogError("Error: " .. tostring(err));
    end
  end)
end,
{
  nargs = '+',
  desc = 'Uninstall one or more vim.pack plugins',
});

require("plugins.fzf");
require("plugins.undotree");
