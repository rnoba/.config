local project = require("build.project");

local MODULE = {};

local C_SOURCE_PATTERNS = {
  "*.c";
  "*.h";
  "*.cc";
  "*.hh";
  "*.cpp";
  "*.hpp";
  "*.cxx";
  "*.hxx";
};

local running = false;
local pending = false;

function MODULE.Path()
  return vim.fs.joinpath(project.Root(), ".tags");
end

function MODULE.Generate(options)
  options = options or {};

  if not system.TestProgram("ctags") then
    if not options.silent then
      system.LogError("Required program not found: ctags");
    end
    return false;
  end

  if running then
    pending = true;
    return true;
  end

  local root      = project.Root();
  local tags_file = vim.fs.joinpath(root, ".tags");

  running = true;

  vim.system({
    "ctags";
    "--languages=C,C++";
    "--exclude=.git";
    "--exclude=build";
    "--exclude=.cache";
    "-R";
    "-f";
    tags_file;
    ".";
  }, {
    cwd  = root;
    text = true;
  }, function(result)
    vim.schedule(function()
      running = false;

      if result.code == 0 then
        if not options.silent then
          system.LogInfo("Tags updated: " .. tags_file);
        end
      elseif not options.silent then
        local message = vim.trim(table.concat({
          result.stderr or "";
          result.stdout or "";
        }, "\n"));

        system.LogError(message ~= "" and message or "ctags failed");
      end

      if pending then
        pending = false;
        MODULE.Generate({ silent = true; });
      end
    end);
  end);

  return true;
end

function MODULE.Ensure()
  if vim.fn.filereadable(MODULE.Path()) == 1 then
    return true;
  end

  MODULE.Generate({ silent = true; });
  system.LogWarn("Tags are being generated. Retry when complete.");
  return false;
end

function MODULE.Setup()
  vim.opt.tags:prepend("./.tags;");

  vim.api.nvim_create_user_command("TagsUpdate", function()
    MODULE.Generate();
  end, {
    desc = "Generate C/C++ project tags.";
  });

  vim.api.nvim_create_user_command("TagsClear", function()
    local tags_file = MODULE.Path();

    if vim.fn.delete(tags_file) == 0 then
      system.LogInfo("Removed: " .. tags_file);
    else
      system.LogWarn("Could not remove: " .. tags_file);
    end
  end, {
    desc = "Remove the project tags file.";
  });

  vim.api.nvim_create_autocmd("BufWritePost", {
    group   = vim.api.nvim_create_augroup("rnoba-ctags-update", { clear = true; });
    pattern = C_SOURCE_PATTERNS;
    callback = function()
      if vim.fn.filereadable(MODULE.Path()) == 1 then
        MODULE.Generate({ silent = true; });
      end
    end;
  });
end

return MODULE;
