local quickfix = require("build.ui.quickfix");
local styles   = require("ui.styles");

local MODULE = {};

local function panel_height(line_count)
  local maximum = math.max(6, math.floor(vim.o.lines * 0.35));
  return math.min(math.max(line_count, 3), maximum);
end

local function clear_matches(window)
  local matches = vim.w[window].rnoba_build_matches or {};

  vim.api.nvim_win_call(window, function()
    for _, id in ipairs(matches) do
      pcall(vim.fn.matchdelete, id);
    end
  end);

  vim.w[window].rnoba_build_matches = {};
end

local function configure_matches(window)
  clear_matches(window);

  local matches = {};
  vim.api.nvim_win_call(window, function()
    matches[#matches + 1] = vim.fn.matchadd("DiagnosticError", [[^ E  ]]);
    matches[#matches + 1] = vim.fn.matchadd("DiagnosticWarn", [[^ W  ]]);
    matches[#matches + 1] = vim.fn.matchadd("DiagnosticInfo", [[^ I  ]]);
    matches[#matches + 1] = vim.fn.matchadd("Comment", [[│]]);
  end);

  vim.w[window].rnoba_build_matches = matches;
end

local function configure(window)
  if not vim.api.nvim_win_is_valid(window) then
    return;
  end

  local list = vim.fn.getqflist({
    items   = 0;
    context = 0;
  });

  local context = list.context or {};
  if context.rnoba_build ~= true then
    return;
  end

  local buffer         = vim.api.nvim_win_get_buf(window);
  local summary, group = quickfix.Summary(list.items or {});

  styles.ApplyPanel(window, {
    cursorline   = true;
    winfixheight = true;
  });

  styles.SetPanelWinbar(
    window,
    "Build results · " .. (context.name or "Build"),
    summary,
    group
  );

  configure_matches(window);

  system.Map(
    "<Esc>",
    MODULE.Close,
    "Close build results",
    buffer
  );
  system.Map(
    "<C-c>",
    MODULE.Close,
    "Close build results",
    buffer
  );
end

function MODULE.Close()
  vim.cmd("silent! cclose");
end

function MODULE.Open(items, options)
  options = options or {};

  vim.fn.setqflist({}, " ", {
    title = "Build · " .. (options.name or "Build");
    items = items;
    context = {
      rnoba_build = true;
      name        = options.name or "Build";
      root        = options.root;
    };
    quickfixtextfunc = "v:lua.RnobaBuildQuickfixText";
  });

  MODULE.OpenCurrent();
end

function MODULE.OpenCurrent()
  local list    = vim.fn.getqflist({ size = 0; context = 0; });
  local context = list.context or {};

  if context.rnoba_build ~= true or list.size == 0 then
    system.LogWarn("No build results available.");
    return;
  end

  local previous = vim.api.nvim_get_current_win();

  vim.cmd("botright copen " .. panel_height(list.size));
  configure(vim.api.nvim_get_current_win());

  if vim.api.nvim_win_is_valid(previous) then
    vim.api.nvim_set_current_win(previous);
  end
end

function MODULE.Clear()
  MODULE.Close();

  vim.fn.setqflist({}, " ", {
    title = "Build";
    items = {};
    context = {
      rnoba_build = true;
    };
    quickfixtextfunc = "v:lua.RnobaBuildQuickfixText";
  });
end

_G.RnobaBuildQuickfixText = function(info)
  return quickfix.Text(info);
end

vim.api.nvim_create_autocmd("FileType", {
  group   = vim.api.nvim_create_augroup("rnoba-build-results-window", { clear = true; });
  pattern = "qf";
  callback = function()
    configure(vim.api.nvim_get_current_win());
  end;
});

return MODULE;
