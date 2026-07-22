local output  = require("build.ui.output");
local results = require("build.ui.results");

local MODULE = {};

local owner_buffer = nil;
local owner_window = nil;
local closing_owner = false;

local function owner_is_open()
  return owner_buffer
  and owner_window
  and vim.api.nvim_buf_is_valid(owner_buffer)
  and vim.api.nvim_win_is_valid(owner_window)
  and vim.api.nvim_win_get_buf(owner_window) == owner_buffer;
end

local function close_owned_panels()
  if closing_owner then
    return;
  end

  closing_owner = true;

  output.Close();
  results.Close();

  owner_buffer = nil;
  owner_window = nil;
  closing_owner = false;
end

function MODULE.SetOwner(buffer, window)
  owner_buffer = buffer;
  owner_window = window;
end

function MODULE.RecordOutput(lines, options)
  output.Record(lines, options);
end

function MODULE.OpenOutput(options)
  if owner_is_open() then
    output.Open(options);
  end
end

function MODULE.OpenResults(items, options)
  if owner_is_open() then
    results.Open(items, options);
  end
end

function MODULE.ClearResults()
  results.Clear();
end

function MODULE.Reset()
  output.Reset();
  results.Clear();
end

local owner_group = vim.api.nvim_create_augroup("rnoba-build-owner", {
  clear = true;
});

vim.api.nvim_create_autocmd("QuitPre", {
  group = owner_group;
  callback = function()
    if owner_window == vim.api.nvim_get_current_win() then
      close_owned_panels();
    end
  end;
});

vim.api.nvim_create_autocmd({
  "BufDelete";
  "BufWipeout";
}, {
  group = owner_group;
  callback = function(event)
    if event.buf == owner_buffer then
      close_owned_panels();
    end
  end;
});

vim.api.nvim_create_user_command("BuildOutput", function()
  if owner_is_open() then
    output.Toggle();
  end
end, {
  desc = "Toggle the latest raw build output.";
});

vim.api.nvim_create_user_command("BuildResults", function()
  if owner_is_open() then
    results.OpenCurrent();
  end
end, {
  desc = "Open the latest build results.";
});

return MODULE;
