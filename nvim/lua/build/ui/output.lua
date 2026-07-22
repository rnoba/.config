local styles = require("ui.styles");

local MODULE = {};

local NAMESPACE = vim.api.nvim_create_namespace("rnoba-build-output");

local buffer         = nil;
local window         = nil;
local lines          = {};
local close_callback = nil;

local info = {
  name   = "Build";
  status = "output";
  group  = "RnobaPanelMuted";
};

local function panel_height(line_count)
  local maximum = math.max(6, math.floor(vim.o.lines * 0.35));
  return math.min(math.max(line_count, 3), maximum);
end

local function resize(height)
  vim.api.nvim_win_call(window, function()
    vim.cmd("resize " .. height);
  end);
end

local function set_highlights(display_lines)
  vim.api.nvim_buf_clear_namespace(buffer, NAMESPACE, 0, -1);

  for index, line in ipairs(display_lines) do
    local highlight = nil;
    local lower     = line:lower();

    if lower:find("fatal error:", 1, true) or lower:find("error:", 1, true) then
      highlight = "DiagnosticError";
    elseif lower:find("warning:", 1, true) then
      highlight = "DiagnosticWarn";
    elseif lower:find("note:", 1, true) then
      highlight = "DiagnosticInfo";
    end

    if highlight then
      vim.api.nvim_buf_add_highlight(
        buffer,
        NAMESPACE,
        highlight,
        index - 1,
        0,
        -1
      );
    end
  end
end

local function close()
  if window and vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_win_close(window, true);
  end

  window = nil;
end

local function create_buffer()
  local result = vim.api.nvim_create_buf(false, true);

  vim.api.nvim_buf_set_name(result, "[Build Output]");

  vim.bo[result].buftype   = "nofile";
  vim.bo[result].bufhidden = "wipe";
  vim.bo[result].buflisted = false;
  vim.bo[result].swapfile  = false;
  vim.bo[result].filetype  = "buildoutput";

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = result;
    once   = true;
    callback = function()
      local callback = close_callback;

      buffer         = nil;
      window         = nil;
      close_callback = nil;

      if callback then
        callback();
      end
    end;
  });

  return result;
end

local function configure()
  styles.ApplyPanel(window, {
    cursorline   = false;
    winfixheight = true;
  });

  local summary = string.format(
    "%s · %d line%s",
    info.status,
    #lines,
    #lines == 1 and "" or "s"
  );

  styles.SetPanelWinbar(
    window,
    "Build output · " .. info.name,
    summary,
    info.group
  );

  for _, key in ipairs({ "q"; "<Esc>"; "<C-c>"; }) do
    system.Map(
      key,
      close,
      "Close build output",
      buffer
    );
  end
end

function MODULE.Record(output, options)
  options = options or {};

  lines = vim.deepcopy(output or {});
  info = {
    name   = options.name or "Build";
    status = options.status or "output";
    group  = options.group or "RnobaPanelMuted";
  };

  if window and vim.api.nvim_win_is_valid(window) then
    MODULE.Open({ allow_empty = true; });
  end
end

function MODULE.Open(options)
  options = options or {};

  if #lines == 0 and options.allow_empty ~= true then
    system.LogWarn("No build output available.");
    return;
  end

  if options.on_close ~= nil then
    close_callback = options.on_close;
  end

  local display_lines = #lines > 0 and lines or { "No standard output."; };
  local previous      = vim.api.nvim_get_current_win();

  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    buffer = create_buffer();
  end

  if not window or not vim.api.nvim_win_is_valid(window) then
    vim.cmd("botright split");
    window = vim.api.nvim_get_current_win();
    vim.api.nvim_win_set_buf(window, buffer);
  end

  vim.bo[buffer].modifiable = true;
  vim.bo[buffer].readonly   = false;
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, display_lines);
  vim.bo[buffer].modifiable = false;
  vim.bo[buffer].readonly   = true;

  set_highlights(display_lines);
  configure();
  resize(panel_height(#display_lines));

  if options.focus == true then
    vim.api.nvim_set_current_win(window);
  elseif vim.api.nvim_win_is_valid(previous) then
    vim.api.nvim_set_current_win(previous);
  end
end

function MODULE.Toggle()
  if window and vim.api.nvim_win_is_valid(window) then
    close();
    return;
  end

  MODULE.Open({ allow_empty = true; });
end

function MODULE.Close()
  close();
end

function MODULE.Reset()
  close_callback = nil;
  close();

  lines = {};
  info = {
    name   = "Build";
    status = "output";
    group  = "RnobaPanelMuted";
  };
end

return MODULE;
