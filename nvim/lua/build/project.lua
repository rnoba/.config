local MODULE = {};

local BUILD_SCRIPT_NAME = "build.sh";

if system.Os() == "Windows" then
  BUILD_SCRIPT_NAME = "build.bat";
end

local function find_file(name)
  local matches = vim.fs.find(name, {
    path   = system.BufferDirectory();
    upward = true;
    type   = "file";
    stop   = vim.uv.os_homedir();
  });

  return matches[1];
end

function MODULE.BuildScriptName()
  return BUILD_SCRIPT_NAME;
end

function MODULE.FindBuildFile()
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

function MODULE.Root()
  local build_file = MODULE.FindBuildFile();
  if build_file then
    return vim.fs.dirname(build_file.path);
  end

  return vim.fs.root(system.BufferDirectory(), {
    ".git";
  }) or vim.fn.getcwd();
end

function MODULE.Command(build_file)
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

return MODULE;
