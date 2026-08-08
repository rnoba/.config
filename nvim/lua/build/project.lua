local _MODULE = {};

local OS  = base.Os();
local BIT = rawget(_G, "bit") or rawget(_G, "bit32");

local BUILD_SCRIPT_NAME = OS == "Windows" and "build.bat" or "build.sh";
local SELECTED          = {};
local SKIP_DIRECTORIES = {
  [".git"]         = true;
  [".hg"]          = true;
  [".svn"]         = true;
  [".cache"]       = true;
  [".venv"]        = true;
  ["node_modules"] = true;
  ["venv"]         = true;
};

local function project_root()
  local directory = base.BufferDirectory();

  return vim.fs.root(directory, {
    BUILD_SCRIPT_NAME;
    ".git";
    "Makefile";
  }) or directory;
end

local function find_build_file()
  local root        = project_root();
  local script      = vim.fs.joinpath(root, BUILD_SCRIPT_NAME);
  local script_stat = vim.uv.fs_stat(script);
  if script_stat and script_stat.type == "file" then
    return { kind = "script"; path = script; name = BUILD_SCRIPT_NAME };
  end

  local makefile      = vim.fs.joinpath(root, "Makefile");
  local makefile_stat = vim.uv.fs_stat(makefile);
  if makefile_stat and makefile_stat.type == "file" then
    return { kind = "make"; path = makefile; name = "Makefile" };
  end

  return nil;
end

local function require_program(name)
  if vim.fn.executable(name) == 1 then
    return true;
  end

  return nil, "Required program not found: " .. name;
end

local function build_command(build_file)
  if build_file.kind == "make" then
    local available, message = require_program("make");
    if not available then
      return nil, message;
    end
    return { "make"; "-f"; build_file.path; };
  end

  local shell              = OS == "Windows" and "cmd" or "bash";
  local available, message = require_program(shell);
  if not available then
    return nil, message;
  end
  if OS == "Windows" then
    return { shell; "/C"; build_file.path; };
  end
  return { shell; build_file.path; };
end

--

local function file_read_bytes(path, amount)
  local file = io.open(path, "rb");
  if not file then
    return nil;
  end

  local header = file:read(amount);
  file:close();
  return header;
end

local function is_executable(path, stat)
  local result = false;

  if OS == "Windows" then
    result = path:lower():sub(-4) == ".exe" and
            file_read_bytes(path, 2) == "MZ";
  else
    result = BIT and BIT.band(stat.mode, 0x49) ~= 0
                 and file_read_bytes(path, 4) == "\127ELF";
  end

  return result;
end

local function file_metadata(stat)
  local modified = stat.mtime or {};

  return {
    size = stat.size     or 0;
    sec  = modified.sec  or 0;
    nsec = modified.nsec or 0;
  };
end

local function scan_directory(dir, snapshot)
  for name, kind in vim.fs.dir(dir) do
    local path = vim.fs.joinpath(dir, name);

    if kind == "directory" and not SKIP_DIRECTORIES[name] then
      scan_directory(path, snapshot);
    elseif kind == "file" then

      local stat = vim.uv.fs_stat(path);
      if stat and is_executable(path, stat) then
        snapshot[path] = file_metadata(stat); 
      end

    end

  end
end

local function file_changed(previous, current)
  return not previous
         or previous.size ~= current.size
         or previous.sec  ~= current.sec
         or previous.nsec ~= current.nsec;
end

local function sorted_paths(snapshot, previous)
  local candidates = {};

  for path, current in pairs(snapshot) do
    if not previous or file_changed(previous[path], current) then
      candidates[#candidates + 1] = {
        path = path;
        sec  = current.sec;
        nsec = current.nsec;
      };
    end
  end

  table.sort(candidates, function(a, b)
    if a.sec  ~= b.sec  then return a.sec  > b.sec;  end
    if a.nsec ~= b.nsec then return a.nsec > b.nsec; end
    return a.path < b.path;
  end);

  return vim.tbl_map(function(candidate) return candidate.path; end, candidates);
end

local function build_file()
  local build_file = find_build_file();

  if not build_file then
    return nil, "Could not find '" .. BUILD_SCRIPT_NAME .. "' or 'Makefile'.";
  end

  local command, message = build_command(build_file);
  if not command then
    return nil, message;
  end

  build_file.path    = vim.fs.normalize(build_file.path);
  build_file.root    = vim.fs.dirname(build_file.path);
  build_file.command = command;
  return build_file;
end

local function snapshot(root)
  local result = {};
  scan_directory(root, result);
  return result;
end

local function resolve(root, previous, callback)
  local selected   = SELECTED[root];
  local current    = snapshot(root);
  local candidates = sorted_paths(current, previous);

  if #candidates == 0 then
    candidates = sorted_paths(current);
  end

  if #candidates == 0 then
    callback(nil); return;
  end

  if selected and vim.tbl_contains(candidates, selected) then
    callback(selected); return;
  end

  if #candidates == 1 then
    SELECTED[root] = candidates[1];
    callback(candidates[1]); return;
  end

  vim.ui.select(
    candidates,
    {
      prompt      = "Select program to run: ";
      format_item = function(path)
        return base.RelativePath(root, path);
      end;
    },
    function(path)
      if path then
        SELECTED[root] = path;
      end
      callback(path);
    end
  );
end

function _MODULE.BuildFile()
  return build_file();
end

function _MODULE.Snapshot(root)
  return snapshot(root);
end

function _MODULE.Resolve(root, previous, callback)
  return resolve(root, previous, callback);
end

function _MODULE.Root()
  return project_root();
end

return _MODULE;
