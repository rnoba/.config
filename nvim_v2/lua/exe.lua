local MODULE = {};

local SELECTED = {};
local SKIP_DIRECTORIES = {
  [".git"]         = true;
  [".hg"]          = true;
  [".svn"]         = true;
  [".cache"]       = true;
  [".venv"]        = true;
  ["node_modules"] = true;
  ["venv"]         = true;
};

local function contains(paths, path)
  for _, candidate in ipairs(paths) do
    if candidate == path then
      return true;
    end
  end

  return false;
end

local function read_header(path)
  local file = io.open(path, "rb");
  if not file then
    return nil;
  end

  local header = file:read(4);

  file:close();
  return header;
end

local function has_execute_permission(mode)
  if bit then
    return bit.band(mode, 73) ~= 0;
  end
  local permissions = mode % 512;
  return math.floor(permissions / 64) % 2 == 1 or
         math.floor(permissions / 8)  % 2 == 1 or
         permissions % 2 == 1;
end

local function is_executable(path, stat)
  local header = read_header(path);
  if not header then
    return false;
  end

  if base.Os() == "Windows" then
    return path:lower():sub(-4) == ".exe" and header:sub(1, 2) == "MZ";
  end

  if base.Os() == "Linux" then
    return has_execute_permission(stat.mode) and header == "\127ELF";
  end

  return false;
end

local function metadata(stat)
  local modified = stat.mtime or {};
  return {
    size = stat.size     or 0;
    sec  = modified.sec  or 0;
    nsec = modified.nsec or 0;
  };
end

local function scan_directory(directory, snapshot)
  pcall(function()
    for name, kind in vim.fs.dir(directory) do
      local path = vim.fs.joinpath(directory, name);

      if kind == "directory" then
        if not SKIP_DIRECTORIES[name] then
          scan_directory(path, snapshot);
        end
      elseif kind == "file" then
        local stat = vim.uv.fs_stat(path);
        if stat and is_executable(path, stat) then
          snapshot[vim.fs.normalize(path)] = metadata(stat);
        end
      end

    end
  end);
end

local function changed(previous, current)
  if not previous then
    return true;
  end

  return previous.size ~= current.size or
         previous.sec  ~= current.sec  or
         previous.nsec ~= current.nsec;
end

local function paths(snapshot, previous)
  local result = {};

  for path, current in pairs(snapshot) do
    if not previous or changed(previous[path], current) then
      result[#result + 1] = {
        path = path;
        sec  = current.sec;
        nsec = current.nsec;
      };
    end
  end

  table.sort(result, function(a, b)
    if a.sec ~= b.sec then
      return a.sec > b.sec;
    end
    if a.nsec ~= b.nsec then
      return a.nsec > b.nsec;
    end
    return a.path < b.path;
  end);

  return vim.tbl_map(function(item) return item.path; end, result);
end

function MODULE.Snapshot(root)
  local snapshot = {};

  scan_directory(root, snapshot);
  return snapshot;
end

function MODULE.Changed(previous, current)
  return paths(current, previous);
end

function MODULE.All(snapshot)
  return paths(snapshot);
end

function MODULE.Resolve(root, previous, callback)
  local current    = MODULE.Snapshot(root);
  local candidates = MODULE.Changed(previous, current);
  local program    = SELECTED[root];

  if #candidates == 0 then
    if program and current[program] then
      candidates = { program; };
    else
      candidates = MODULE.All(current);
    end
  end

  if program and contains(candidates, program) then
    callback(program);
    return;
  end

  if #candidates == 0 then
    callback(nil);
    return;
  end

  if #candidates == 1 then
    SELECTED[root] = candidates[1];
    callback(candidates[1]);
    return;
  end

  vim.ui.select(
    candidates,
    {
      prompt      = "Select program to run:";
      format_item = function(path) return base.RelativePath(root, path); end;
    }, function(path)
      if path then
        SELECTED[root] = path;
      end

      callback(path);
    end
  );
end

return MODULE;
