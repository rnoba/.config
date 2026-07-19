local fzf = require("fzf-lua");

local SERVERS = {
  ts_ls = {
    cmd  = { "bunx", "typescript-language-server", "--stdio" },
    test = function()
      local result = system.TestProgram("bunx"); 
      if result then
        system.LogError("Could not find required program for typescript LSP: 'bunx'");
      end
      return result;
    end
  },
  -- nixd = {},
  -- prismals = {},
  -- tailwindcss = {},
  -- gopls = {},
  -- svelte = {},
  -- pyright = {},
  -- lua_ls = {
  --   settings = {
  --     Lua = {
  --       completion = {
  --         callSnippet = "Replace",
  --       },
  --     },
  --   },
  -- },
}

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("rnoba-lsp-attach", { clear = true }),

  callback = function(event)
    system.SetLspAttached(true);

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

    local client = vim.lsp.get_client_by_id(event.data.client_id);

    if not client then
      return;
    end

    local function client_supports_method(method)
      return client:supports_method(method, event.buf);
    end

    if client_supports_method(vim.lsp.protocol.Methods.textDocument_completion) then
      vim.lsp.completion.enable(true, client.id, event.buf, {
        autotrigger = false,
      });
    end

    if client_supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
      local highlight_group = vim.api.nvim_create_augroup("rnoba-lsp-highlight", {
        clear = false,
      });

      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer   = event.buf,
        group    = highlight_group,
        callback = vim.lsp.buf.document_highlight,
      });

      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer   = event.buf,
        group    = highlight_group,
        callback = vim.lsp.buf.clear_references,
      });

      vim.api.nvim_create_autocmd("LspDetach", {
        buffer = event.buf,
        group  = highlight_group,
        once   = true,

        callback = function()
          system.SetLspAttached(false);
          vim.lsp.buf.clear_references();
          vim.api.nvim_clear_autocmds({
            group  = highlight_group,
            buffer = event.buf,
          });
        end,
      })
    end

    if client_supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      system.Map(
        "<leader>th",
        function()
          local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf });
          vim.lsp.inlay_hint.enable(not enabled, { bufnr = event.buf });
        end,
        "[T]oggle Inlay [H]ints",
        event.buf
      );

    end
  end,
})

vim.diagnostic.config({
  severity_sort = true,
  float = {
    border = "rounded",
    source = "if_many",
  },
  underline = {
    severity = vim.diagnostic.severity.ERROR,
  },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚 ",
      [vim.diagnostic.severity.WARN]  = "󰀪 ",
      [vim.diagnostic.severity.INFO]  = "󰋽 ",
      [vim.diagnostic.severity.HINT]  = "󰌶 ",
    },
  } or {},
  virtual_text = {
    source = "if_many",
    spacing = 2,
    format = function(diagnostic)
      return diagnostic.message;
    end,
  },
})

local capabilities = vim.lsp.protocol.make_client_capabilities();

local function setup(server_name)
  local server = SERVERS[server_name] or {};
  if server.test() then
    local config = vim.tbl_deep_extend("force", {}, server, {
      capabilities = vim.tbl_deep_extend(
        "force",
        {},
        capabilities,
        server.capabilities or {}
      ),
    });

    vim.lsp.config(server_name, config);
    vim.lsp.enable(server_name);
  end
end

for _, server_name in ipairs(vim.tbl_keys(SERVERS)) do
  setup(server_name)
end
