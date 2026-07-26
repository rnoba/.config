local process  = require("process");
local project  = require("project");
local result   = require("result");
local output   = require("output");
local quickfix = require("quickfix");
local exe      = require("exe");

local PARENT_WINDOW  = nil;
local PARENT_BUFFER  = nil;
local CLOSING        = false;

local function run_program(path, root)
  local process, spawn_error = output.Start({
    command = { path };
    cwd     = root;
    name    = vim.fn.fnamemodify(path, ":t");
  });

  if not process then
    base.LogError(spawn_error);
  end
end

local function run_build()
  local build_file, message = project.Resolve();
  if not build_file then
    base.LogError(message); return;
  end
  PARENT_WINDOW = vim.api.nvim_get_current_win();
  PARENT_BUFFER = vim.api.nvim_win_get_buf(PARENT_WINDOW);
  vim.cmd("silent! wall");
  quickfix.Clear();
  output.Reset();

  local snapshot = exe.Snapshot(build_file.root);
  local running, spawn_error = process.Run({
    command = build_file.command;
    kind    = "system";
    cwd     = build_file.root;
    on_finish = function(completed)
      local parsed = result.ParseBuild(completed);

      if parsed.success then
        exe.Resolve(
          build_file.root,
          snapshot,
          function(result)
            run_program(result, build_file.root);
          end
        );
      else
        output.Close();
      end

      if #parsed.items > 0 then
        quickfix.Open(parsed.items, { name = build_file.name; root = build_file.root; });
      else
        quickfix.Close();
      end

    end;
  });

  if not running and spawn_error then
    base.LogError(spawn_error);
  end
end

vim.api.nvim_create_autocmd(
  "BufEnter",
  {
    group    = vim.api.nvim_create_augroup("rnoba-project-build-mappings", { clear = true; });
    callback = function(event)
      if vim.bo[event.buf].buftype ~= "" then
        return;
      end

      if PARENT_BUFFER and event.buf ~= PARENT_BUFFER then
        return;
      end


      base.Map(
        "<C-b>",
        run_build,
        "Build, run, or stop project",
        event.buf
      );

    end;
  }
);

local function close_owned_panels()
  if CLOSING then
    return;
  end;

  CLOSING = true;

  quickfix.Close();
  output.Stop();
  output.Close();

  CLOSING       = false;
  PARENT_WINDOW = nil;
  PARENT_BUFFER = nil;
end

local PARENT_GROUP = vim.api.nvim_create_augroup("rnoba-build-parent", { clear = true });

vim.api.nvim_create_autocmd(
  "QuitPre",
  {
    group = PARENT_GROUP;
    callback = function()
      if PARENT_WINDOW == vim.api.nvim_get_current_win() then
        close_owned_panels();
      end
    end;
  }
);

vim.api.nvim_create_autocmd(
  {
    "BufDelete";
    "BufWipeout";
  },
  {
    group = PARENT_GROUP;
    callback = function(event)
      if event.buf == PARENT_BUFFER then
        close_owned_panels();
      end
    end;
  }
);

