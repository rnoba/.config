local fzf = require("fzf-lua");

local SERVERS = {
  ts_ls = {
    cmd = {
      "bunx";
      "typescript-language-server";
      "--stdio";
    };

    filetypes = {
      "javascript";
      "javascriptreact";
      "typescript";
      "typescriptreact";
    };

    init_options = {
      hostInfo = "neovim";
    };

    root_dir = function(bufnr, on_dir)
      local buffer_name = system.BufferName(bufnr);

      if buffer_name == "" then
        return;
      end

      if vim.fn.isdirectory(buffer_name) == 1 then
        return;
      end

      local root_markers = {
        {
          "package-lock.json";
          "yarn.lock";
          "pnpm-lock.yaml";
          "bun.lock";
          "bun.lockb";
        };
        {
          ".git";
        };
      };

      local project_root = vim.fs.root(bufnr, root_markers);
      local deno_root    = vim.fs.root(bufnr, {
        "deno.json";
        "deno.jsonc";
      });

      local deno_lock_root = vim.fs.root(bufnr, {
        "deno.lock";
      });

      if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then
        return;
      end

      if deno_root and (not project_root or #deno_root >= #project_root) then
        return;
      end

      on_dir(project_root or vim.fs.dirname(buffer_name));
    end;

    test = function()
      local result = system.TestProgram("bunx");

      if not result then
        system.LogError("Could not find required program for TypeScript LSP: 'bunx'");
      end

      return result;
    end;
  };
  nixd = {
    cmd = { "nixd"; };
    filetypes = {
      "nix";
    };
    root_markers = {
      "flake.nix";
      ".git";
    };

    test = function()
      return system.TestProgram("nixd");
    end;
  };

  -- prismals = {};
  -- tailwindcss = {};
  -- gopls = {};
  -- svelte = {};
  -- pyright = {};

  lua_ls = {
    filetypes = {
      "lua";
    };

    root_markers = {
      ".luarc.json";
      ".luarc.jsonc";
      ".git";
    };

    settings = {
      Lua = {
        completion = {
          callSnippet = "Replace";
        };
      };
    };
  };

};

local LSP_ATTACH_GROUP = vim.api.nvim_create_augroup(
  "rnoba-lsp-attach",
  {
    clear = true;
  }
);

local function clear_lsp_references(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return;
  end

  vim.api.nvim_buf_call(bufnr, function()
    vim.lsp.buf.clear_references();
  end);
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = LSP_ATTACH_GROUP;

  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id);

    if not client then
      return;
    end

    system.Map(
      "gO",
      fzf.lsp_document_symbols,
      "Open Document Symbols",
      event.buf
    );

    system.Map(
      "gd",
      fzf.lsp_definitions,
      "[G]oto [D]efinition",
      event.buf
    );

    system.Map(
      "gr",
      fzf.lsp_references,
      "[G]oto [R]eferences",
      event.buf
    );

    system.Map(
      "gu",
      fzf.lsp_implementations,
      "[G]oto [I]mplementation",
      event.buf
    );

    system.Map(
      "<leader>D",
      fzf.lsp_typedefs,
      "Type [D]efinition",
      event.buf
    );

    system.Map(
      "<leader>ws",
      fzf.lsp_live_workspace_symbols,
      "[W]orkspace [S]ymbols",
      event.buf
    );

    system.Map(
      "<leader>rn",
      vim.lsp.buf.rename,
      "[R]e[n]ame",
      event.buf
    );

    system.Map(
      "<leader>ca",
      vim.lsp.buf.code_action,
      "[C]ode [A]ction",
      event.buf
    );

    system.Map(
      "gD",
      vim.lsp.buf.declaration,
      "[G]oto [D]eclaration",
      event.buf
    );

    local function client_supports_method(method)
      return client:supports_method(method, event.buf);
    end

    if client_supports_method(vim.lsp.protocol.Methods.textDocument_completion) then
      vim.lsp.completion.enable(
        true,
        client.id,
        event.buf,
        {
          autotrigger = false;
        }
      );
    end

    if client_supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
      local highlight_group = vim.api.nvim_create_augroup(
        "rnoba-lsp-highlight-" .. event.buf,
        {
          clear = true;
        }
      );

      vim.api.nvim_create_autocmd({
        "CursorHold";
        "CursorHoldI";
      }, {
        buffer = event.buf;
        group = highlight_group;

        callback = function(args)
          if not system.IsFileBuffer(args.buf) then
            return;
          end

          vim.lsp.buf.document_highlight();
        end
      });

      vim.api.nvim_create_autocmd({
        "CursorMoved";
        "CursorMovedI";
      }, {
        buffer = event.buf;
        group  = highlight_group;

        callback = function(args)
          clear_lsp_references(args.buf);
        end
      });

      vim.api.nvim_create_autocmd("LspDetach", {
        buffer = event.buf;
        group = highlight_group;
        once = true;

        callback = function(args)
          clear_lsp_references(args.buf);

          vim.api.nvim_clear_autocmds({
            group  = highlight_group;
            buffer = args.buf;
          });
        end
      });
    end

    if client_supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      system.Map(
        "<leader>th",
        function()
          local enabled = vim.lsp.inlay_hint.is_enabled({
            bufnr = event.buf;
          });

          vim.lsp.inlay_hint.enable(not enabled, {
            bufnr = event.buf;
          });
        end,
        "[T]oggle Inlay [H]ints",
        event.buf
      );
    end
  end
});

vim.api.nvim_create_autocmd("LspDetach", {
  group = LSP_ATTACH_GROUP;

  callback = function(event)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(event.buf) then
        return;
      end

      local clients = vim.lsp.get_clients({
        bufnr = event.buf;
      });

    end);
  end;
});

vim.diagnostic.config({
  severity_sort = true;

  float = {
    border = "rounded";
    source = "if_many";
  };

  underline = {
    severity = vim.diagnostic.severity.ERROR;
  };

  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚 ";
      [vim.diagnostic.severity.WARN]  = "󰀪 ";
      [vim.diagnostic.severity.INFO]  = "󰋽 ";
      [vim.diagnostic.severity.HINT]  = "󰌶 ";
    };
  } or {};

  virtual_text = {
    source = "if_many";
    spacing = 2;

    format = function(diagnostic)
      return diagnostic.message;
    end;
  };
});

local capabilities = vim.lsp.protocol.make_client_capabilities();

local function setup(server_name)
  local server = SERVERS[server_name];

  if not server then
    return;
  end

  if server.test and not server.test() then
    return;
  end

  local config = vim.deepcopy(server);
  config.test  = nil;

  config.capabilities = vim.tbl_deep_extend(
    "force",
    {},
    capabilities,
    config.capabilities or {}
  );

  vim.lsp.config(server_name, config);
  vim.lsp.enable(server_name);
end

for _, server_name in ipairs(vim.tbl_keys(SERVERS)) do
  setup(server_name);
end
