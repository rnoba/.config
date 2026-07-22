local MODULE = {};

local BUILD_SCRIPT_NAME = system.Os() == "Windows" and "build.bat" or "build.sh";

local function find_file(name)
  local matches = vim.fs.find(name, {
    path   = system.BufferDirectory();
    upward = true;
    type   = "file";
    stop   = vim.uv.os_homedir();
  });

  return matches[1];
end

local function find_build_file()
  local script = find_file(BUILD_SCRIPT_NAME);
  if script then
    return {
      kind = "script";
      name = BUILD_SCRIPT_NAME;
      path = script;
    };
  end

  local makefile = find_file("Makefile");
  if makefile then
    return {
      kind = "make";
      name = "Makefile";
      path = makefile;
    };
  end

  return nil;
end

local function build_command(build_file)
  if build_file.kind == "make" then
    if not system.TestProgram("make") then
      return nil, "Required program not found: make";
    end

    return {
      "make";
      "-f";
      build_file.path;
    };
  end

  if system.Os() == "Linux" then
    if not system.TestProgram("bash") then
      return nil, "Required program not found: bash";
    end

    return {
      "bash";
      build_file.path;
    };
  end

  if system.Os() == "Windows" then
    if not system.TestProgram("cmd") then
      return nil, "Required program not found: cmd";
    end

    return {
      "cmd";
      "/C";
      build_file.path;
    };
  end

  return nil, "OS not supported";
end

function MODULE.Resolve()
  local build_file = find_build_file();
  if not build_file then
    return nil, "Could not find '" .. BUILD_SCRIPT_NAME .. "' or 'Makefile'.";
  end

  local command, message = build_command(build_file);
  if not command then
    return nil, message;
  end

  build_file.command = command;
  build_file.root    = vim.fs.dirname(build_file.path);

  return build_file;
end

function MODULE.Root()
  local build_file = find_build_file();
  if build_file then
    return vim.fs.dirname(build_file.path);
  end

  return vim.fs.root(system.BufferDirectory(), {
    ".git";
  }) or vim.fn.getcwd();
end

return MODULE;
