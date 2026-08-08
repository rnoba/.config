local project = require("build.project");

local _MODULE = {};

local PROJECT_TAGS_FILE_NAME = ".tags";
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

local function project_tags_path()
  return vim.fs.joinpath(project.Root(), PROJECT_TAGS_FILE_NAME);
end

local running = false;
local pending = false;

local function generate(options)
  local options = options or {};
  if not vim.fn.executable("ctags") == 1 then
    return;
  end

  if running then
    pending = true; return;
  end

  local file = project_tags_path();
  running    = true;
  vim.system({
    "ctags";
    "--languages=C,C++";
    "--sort=yes";
    "--exclude=.git";
    "--exclude=build";
    "--exclude=.cache";
    "-R";
    "-f";
    file;
    ".";
  },
  {  
    cwd  = project.Root();
    text = true;
  },
  function(result)
    vim.schedule(function()
      running = false;

      if result.code == 0 then
        if not options.silent then
          base.LogInfo("tags updated: " .. file);
        end
      else
        base.LogInfo("ctags failed: " .. tostring(result.stderr));
      end

      if pending then
        pending = false;
        generate({ silent = true; });
      end
    end);
  end);
end

local function ensure() 
  local file = project_tags_path();
  if vim.fn.filereadable(file) == 1 then
    return file;
  end
  generate({ silent = true; });
  return nil;
end

vim.opt.tags:prepend("./.tags;");

vim.api.nvim_create_autocmd("BufWritePost", {
  group   = vim.api.nvim_create_augroup("rnoba-ctags-update", { clear = true; });
  pattern = C_SOURCE_PATTERNS;
  callback = function()
    generate();
  end
});

--
local fzf = require("fzf-lua");

local TAG_KINDS = {
  c = "class";
  d = "macro";
  e = "enum";
  f = "function";
  g = "enum member";
  m = "member";
  n = "namespace";
  p = "prototype";
  s = "struct";
  t = "typedef";
  u = "union";
  v = "variable";
};

local function current_tag()
  local tag = vim.fn.expand("<cfile>");
  if tag == "" then
    return nil;
  end
  return tag;
end

local function jump_to_tag(tag, index)
  local command = "tag " .. vim.fn.escape(tag, [[ \|]]);
  if index then
    command = index .. command;
  end
  local ok, message = pcall(vim.cmd, command);
  if not ok then
    base.LogError(tostring(message));
  end
end

local function global_definitions()
  local tag = current_tag();
  if not tag then
    return;
  end

  local matches = vim.fn.taglist("^" .. vim.pesc(tag) .. "$");
  if #matches == 0 then
    base.LogWarn("Could not find tag: '" .. tag .. "'");
    return;
  end

  if #matches == 1 then
    jump_to_tag(tag);
    return;
  end

  vim.ui.select(matches, {
    prompt = string.format("%d definitions found", #matches);
    format_item = function(match)
      local kind     = TAG_KINDS[match.kind] or match.kind or "unknown";
      local path     = vim.fn.fnamemodify(match.filename or "", ":~:.");
      local location = match.cmd and (":" .. match.cmd) or "";

      return string.format(
        "%-12s %-24s %s%s",
        "[" .. kind .. "]",
        match.name or "",
        path,
        location
      );
    end;
  }, function(_, index)
    if index then
      jump_to_tag(tag, index);
    end
  end);
end

local function references()
  fzf.grep_cword({ cwd = project.Root(); });
end

local function project_symbols()
  local tags_file = tags.Ensure();
  if not tags_file then
    return;
  end

  fzf.tags_live_grep({
    cwd        = project.Root();
    ctags_file = tags_file;
  });
end

local function buffer_symbols()
  if vim.fn.executable("ctags") == 1 then
    fzf.btags({ cwd = project.Root(); });
  end
end

local function attach(buffer)
  base.Map(
    "gO",
    buffer_symbols,
    "Open Document Symbols",
    buffer
  );
  base.Map(
    "gd",
    global_definitions,
    "[G]oto Project [D]efinition",
    buffer
  );
  base.Map(
    "gr",
    references,
    "[G]oto [R]eferences",
    buffer
  );
  base.Map(
    "<leader>ws",
    project_symbols,
    "[W]orkspace [S]ymbols",
    buffer
  );
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("rnoba-c-project-maps", {
    clear = true;
  });
  pattern = {
    "c";
    "cpp";
  };
  callback = function(event)
    attach(event.buf);
  end;
});

function _MODULE.generate(options)
  generate(options);
end

return _MODULE;
