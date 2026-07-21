local fzf     = require("fzf-lua");
local project = require("build.project");
local tags    = require("build.tags");

local function is_c_source(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return false;
  end

  local filetype = vim.bo[buffer].filetype;
  return filetype == "c" or filetype == "cpp";
end

local function jump_to_tag()
  if not tags.Ensure() then
    return;
  end

  local tag = vim.fn.expand("<cword>");
  if tag == "" then
    return;
  end

  local matches = vim.fn.taglist("^" .. vim.pesc(tag) .. "$");
  if #matches == 0 then
    system.LogWarn("Could not find tag: '" .. tag .. "'");
    return;
  end

  if #matches == 1 then
    local ok, message = pcall(vim.cmd, "tag " .. vim.fn.escape(tag, [[ \|]]));
    if not ok then
      system.LogError(tostring(message));
    end
    return;
  end

  fzf.tags_grep_cword({
    cwd    = project.Root();
    prompt = "Definitions> ";
    winopts = {
      title     = " " .. tag .. " ";
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
      ["--info"]     = "inline-right";
      ["--header"]   = string.format("%d definitions found", #matches);
    };
  });
end

local function tags_for_word()
  if tags.Ensure() then
    fzf.tags_grep_cword({ cwd = project.Root(); });
  end
end

local function references()
  fzf.grep_cword({ cwd = project.Root(); });
end

local function project_symbols()
  if tags.Ensure() then
    fzf.tags_live_grep({ cwd = project.Root(); });
  end
end

local function buffer_symbols()
  if not system.TestProgram("ctags") then
    system.LogError("Required program not found: ctags");
    return;
  end

  fzf.btags({ cwd = project.Root(); });
end

local function attach(buffer)
  if not is_c_source(buffer) then
    return;
  end

  system.Map(
    "gO",
    buffer_symbols,
    "Open Document Symbols",
    buffer
  );
  system.Map(
    "gd",
    jump_to_tag,
    "[G]oto [D]efinition",
    buffer
  );
  system.Map(
    "gr",
    references,
    "[G]oto [R]eferences",
    buffer
  );
  system.Map(
    "gu",
    tags_for_word,
    "[G]oto [I]mplementation",
    buffer
  );
  system.Map(
    "<leader>D",
    tags_for_word,
    "Type [D]efinition",
    buffer
  );
  system.Map(
    "<leader>ws",
    project_symbols,
    "[W]orkspace [S]ymbols",
    buffer
  );
  system.Map(
    "gD",
    jump_to_tag,
    "[G]oto [D]eclaration",
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
