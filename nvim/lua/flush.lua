local ring = require("ring");

local _MODULE = {};

local FLUSH_PAUSED    = false;
local REDRAW_DELAY_MS = 200;

local function buffer_flush(buffer, capacity, on_render)
  local ring_buffer = ring.New(capacity);
  local timer       = assert(vim.uv.new_timer());

  local dirty  = false;
  local closed = false;

  local function render()
    if closed or not dirty or not vim.api.nvim_buf_is_valid(buffer) then
      return;
    end

    local text  = ring_buffer.text():gsub("\r\n", "\n"):gsub("\r", "\n");
    local lines = {};
    if text ~= "" then
      lines = vim.split(text, "\n", { plain = true });
    end

    vim.bo[buffer].modifiable = true;
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines);
    vim.bo[buffer].modifiable = false;
    vim.bo[buffer].modified   = false;
    dirty = false;
    if on_render then
      on_render(#lines);
    end

  end

  local timer_running = false;
  local function request_render()
    if closed or timer_running then
      return;
    end

    timer_running = true;
    timer:start(REDRAW_DELAY_MS, REDRAW_DELAY_MS, vim.schedule_wrap(function()
      if closed then
        return;
      end

      if dirty then
        render();
      else
        timer:stop();
        timer_running = false;
      end
    end));

  end

  local function push(data)
    if FLUSH_PAUSED or closed or #data <= 0 then
      return;
    end

    local chunk = data;
    if type(data) == "table" then
      chunk = table.concat(data, "\n");
    end

    if chunk ~= "" then
      ring_buffer.push(chunk); dirty = true;
      request_render();
    end
  end

  local function close()
    if closed then
      return;
    end

    render(); closed = true;
    timer:stop();
    if not timer:is_closing() then
      timer:close();
    end
  end

  local function clear()
    ring_buffer.clear(); dirty = true;
    request_render();
  end

  local function pause()
    FLUSH_PAUSED = true;
  end

  local function resume()
    FLUSH_PAUSED = false;
  end

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    buffer   = buffer,
    once     = true,
    callback = close
  });

  return {
    push   = push;
    close  = close;
    render = render;
    clear  = clear;
    pause  = pause;
    resume = resume;
  };
end

function _MODULE.New(buffer, capacity, on_render)
  return buffer_flush(buffer, capacity, on_render);
end

return _MODULE;
