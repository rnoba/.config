local _MODULE = {};

local DEFAULT_CAPACITY = 64*1024;

local function ring_buffer(capacity)
  capacity = capacity or DEFAULT_CAPACITY;

  local chunks = {};
  local first  = 1;
  local last   = 0;
  local size   = 0;

  local function clear()
    chunks = {};
    first  = 1;
    last   = 0;
    size   = 0;
  end

  local function compact()
    if first < 12*1024 or first < (last / 2) then
      return;
    end

    local result = {};
    local count  = 0;
    for idx = first, last do
      count         = count + 1;
      result[count] = chunks[idx];
    end

    chunks = result;
    first  = 1;
    last   = count;
  end

  local function push(chunk)
    local chunk_size = #chunk; 
    if chunk_size <= 0 then
      return;
    end

    if chunk_size >= capacity then
      clear();

      chunks[1] = chunk:sub(chunk_size - capacity + 1);
      last      = 1;
      size      = capacity;
      return;
    end

    last         = last + 1;
    size         = size + chunk_size;
    chunks[last] = chunk;

    local excess = size - capacity;
    while excess > 0 do
      local head      = chunks[first];
      local head_size = #head;

      if excess >= head_size then
        chunks[first] = nil;

        first  = first + 1;
        size   = size   - head_size;
        excess = excess - head_size;
      else
        chunks[first] = chunks[first]:sub(excess + 1);

        size   = size - excess;
        excess = 0;
      end

    end

    compact();
  end

  local function text()
    if size == 0 then
      return "";
    end

    return table.concat(chunks, "", first, last);
  end

  return {
    push  = push;
    text  = text;
    clear = clear;
  }
end

function _MODULE.New(capacity)
  return ring_buffer(capacity);
end

return _MODULE;
