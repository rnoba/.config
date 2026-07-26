local style  = require("style");
local result = require("result");

local MODULE = {};

local WINDOW = nil;
local BUFFER = nil;
local JOB    = nil;

local INFO = {
  title   = "Program output";
  name    = "Program";
  message = "";
  status  = "idle";
  group   = "RnobaPanelMuted";
};

local function buffer_is_valid()
  return BUFFER ~= nil and vim.api.nvim_buf_is_valid(BUFFER);
end

local function window_is_valid()
  return WINDOW ~= nil and vim.api.nvim_win_is_valid(WINDOW);
end

local function job_is_running()
  if JOB == nil then
    return false;
  end

  return vim.fn.jobwait({ JOB }, 0)[1] == -1;
end

local function update_winbar()
  if not window_is_valid() then
    return;
  end

  style.WindowSetWinbar(
    WINDOW,
    INFO.title .. " · " .. INFO.name,
    INFO.status,
    INFO.group
  );
end

local function configure_window()
  if not window_is_valid() then
    return;
  end

  style.WindowSetStyles(WINDOW, {
    cursorline   = false;
    winfixheight = true;
    wrap         = false;
  });

  vim.wo[WINDOW].number         = false;
  vim.wo[WINDOW].relativenumber = false;
  vim.wo[WINDOW].signcolumn     = "no";
  vim.wo[WINDOW].foldenable     = false;
  vim.wo[WINDOW].spell          = false;
end

local function panel_height(line_count)
  local maximum = math.max(6, math.floor(vim.o.lines * 0.35));
  return math.min(math.max(line_count, 3), maximum);
end

local function resize(height)
  vim.api.nvim_win_call(WINDOW, function() vim.cmd("resize " .. height); end);
end
local function attach_output_metadata()
  local line_count = vim.api.nvim_buf_line_count(BUFFER);

  vim.api.nvim_buf_attach(
    BUFFER,
    false,
    {
      on_lines = function(
        _,
        buffer,
        _,
        _,
        old_last_line,
        new_last_line,
        _
      )
      resize(panel_height(line_count));
      line_count = line_count + new_last_line - old_last_line;
    end;
    on_detach = function()
      line_count = 0;
    end
  }
);
end

local function create_window()
  local parent = vim.api.nvim_get_current_win();
  vim.cmd("botright split");

  WINDOW = vim.api.nvim_get_current_win();
  BUFFER = vim.api.nvim_create_buf(false, true); attach_output_metadata(BUFFER);
  vim.api.nvim_win_set_buf(WINDOW, BUFFER);

  if vim.api.nvim_win_is_valid(parent) then
    configure_window();
    vim.api.nvim_set_current_win(parent);
  end

end

local function reset_terminal()
  if window_is_valid() then
    vim.api.nvim_win_close(WINDOW, true);
  end

  WINDOW = nil;
  BUFFER = nil;
  JOB    = nil;

  create_window();
end

function MODULE.Start(options)
  options = options or {};
  assert(type(options.command) == "table" and #options.command > 0, "output.Start requires a command array");

  if job_is_running() then
    vim.fn.jobstop(JOB);
  end

  if options.name ~= nil then
    INFO.name = options.name;
  else
    INFO.name = vim.fn.fnamemodify(options.command[1], ":t");
  end

  if options.title ~= nil then
    INFO.title = options.title;
  end

  INFO.status = "running";

  reset_terminal();
  update_winbar();

  local parent = vim.api.nvim_get_current_win();
  vim.api.nvim_set_current_win(WINDOW);
  JOB = vim.fn.jobstart(
    options.command,
    {
      cwd    = options.cwd;
      env    = options.env;
      term   = true;
      width  = vim.api.nvim_win_get_width(WINDOW);
      height = vim.api.nvim_win_get_height(WINDOW);
      on_exit = function(_, code)
        vim.schedule(function()
          JOB = nil;

          local signal = 0;
          if base.Os() ~= "Windows" and code >= 128 and code <= 255 then
            signal = code - 128;
          end

          local parsed = result.ParseProgram({
            signal = signal,
            code   = code,
          }); 
          INFO.status = parsed.status;
          if buffer_is_valid() then
            vim.bo[BUFFER].modified = false;
          end
          update_winbar();
          if options.callback then
            options.callback(parsed);
          end
        end);
      end;
    }
  );

  if JOB <= 0 then
    local error_code = JOB;

    JOB         = nil;
    INFO.status = "failed to start";

    update_winbar();

    if vim.api.nvim_win_is_valid(parent) then
      vim.api.nvim_set_current_win(parent);
    end

    return nil, string.format("jobstart() failed with status %d", error_code);
  end

  vim.bo[BUFFER].buflisted  = false;
  vim.bo[BUFFER].swapfile   = false;
  vim.bo[BUFFER].scrollback = 1000;
  vim.bo[BUFFER].modified   = false;
  vim.bo[BUFFER].bufhidden  = "wipe";

  base.Map(
    "<Esc>",
    function()
      if job_is_running() then MODULE.Stop(); else MODULE.Close(); end
    end,
    "Close output",
    BUFFER
  );

  base.Map(
    "<C-c>",
    function()
      if job_is_running() then MODULE.Stop(); else MODULE.Close(); end
    end,
    "Close output",
    BUFFER
  );

  vim.bo[BUFFER].modified = false;
  if vim.api.nvim_win_is_valid(parent) then
    vim.api.nvim_set_current_win(parent);
  end

  return {
    handle      = JOB;
    handle_kind = "job";
  };
end

function MODULE.Stop()
  if not job_is_running() then
    return false;
  end
  return vim.fn.jobstop(JOB) == 1;
end

function MODULE.Open()
  if not buffer_is_valid() then
    return false;
  end

  if window_is_valid() then
    return true;
  end

  local parent = vim.api.nvim_get_current_win();
  vim.cmd("botright split");

  WINDOW = vim.api.nvim_get_current_win();
  vim.api.nvim_win_set_buf(WINDOW, BUFFER);

  configure_window();

  update_winbar();

  if vim.api.nvim_win_is_valid(parent) then
    vim.api.nvim_set_current_win(parent);
  end

  return true;
end

function MODULE.Close()
  if window_is_valid() then
    vim.api.nvim_win_close(WINDOW, true);
  end

  WINDOW = nil;
end

function MODULE.Reset()
  MODULE.Stop();
  MODULE.Close();

  WINDOW = nil;
  BUFFER = nil;
  JOB    = nil;

  INFO = {
    title  = "Build output";
    name   = "Build";
    status = "output";
    group  = "RnobaPanelMuted";
  };
end

return MODULE;
