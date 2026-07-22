local fzf     = require("fzf-lua");
local project = require("build.project");
local tags    = require("build.tags");

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
    system.LogError(tostring(message));
  end
end

local function project_definitions()
  local tags_file = tags.Ensure();
  if not tags_file then
    return;
  end

  fzf.tags_grep_cword({
    cwd        = project.Root();
    ctags_file = tags_file;
    prompt     = "Definitions> ";
    winopts = {
      title_pos = "center";
      height    = 0.70;
      width     = 0.85;
      preview = {
        layout   = "vertical";
        vertical = "down:55%";
      };
    };
    fzf_opts = {
      ["--no-multi"] = true;
      ["--select-1"] = true;
      ["--info"]     = "inline-right";
      ["--header"]   = "Project definitions";
    };
  });
end

local function global_definitions()
  local tag = current_tag();
  if not tag then
    return;
  end

  local matches = vim.fn.taglist("^" .. vim.pesc(tag) .. "$");
  if #matches == 0 then
    system.LogWarn("Could not find tag: '" .. tag .. "'");
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
  if not system.TestProgram("ctags") then
    system.LogError("Required program not found: ctags");
    return;
  end

  fzf.btags({ cwd = project.Root(); });
end

local function attach(buffer)
  system.Map(
    "gO",
    buffer_symbols,
    "Open Document Symbols",
    buffer
  );
  system.Map(
    "gd",
    project_definitions,
    "[G]oto Project [D]efinition",
    buffer
  );
  system.Map(
    "gD",
    global_definitions,
    "[G]oto Global [D]efinition",
    buffer
  );
  system.Map(
    "gr",
    references,
    "[G]oto [R]eferences",
    buffer
  );
  system.Map(
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
