local nvim_lsp = require("lspconfig")
local nullls = require("null-ls")
local capabilities = require("cmp_nvim_lsp").update_capabilities(vim.lsp.protocol.make_client_capabilities())
local lsp_installer = require("nvim-lsp-installer")

-- Mappings.
local map_opts = { noremap = true, silent = true }
vim.api.nvim_set_keymap("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>", map_opts)
vim.api.nvim_set_keymap("n", "<space>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", map_opts)

local on_attach = function(client, bufnr)
  local function buf_set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end

  buf_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.type_definition()<CR>", map_opts)
  buf_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", map_opts)
  buf_set_keymap("n", "gj", "<cmd>Lspsaga diagnostic_jump_next<CR>", map_opts)
  buf_set_keymap("n", "gk", "<cmd>Lspsaga diagnostic_jump_prev<CR>", map_opts)
  buf_set_keymap("n", "K", "<cmd>Lspsaga hover_doc<CR>", map_opts)
  buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", map_opts)
  buf_set_keymap("n", "<C-k>", "<cmd>Lspsaga signature_help<CR>", map_opts)
  buf_set_keymap("n", "<leader>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", map_opts)
  buf_set_keymap("n", "<leader>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", map_opts)
  buf_set_keymap("n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", map_opts)
  buf_set_keymap("n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", map_opts)
  buf_set_keymap("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", map_opts)
  buf_set_keymap("n", "<leader>ac", "<cmd>Lspsaga code_action<CR>", map_opts)
  -- buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", map_opts)
  buf_set_keymap("n", "<leader>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", map_opts)
end

local runtime_path = vim.split(package.path, ";")
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")

local function detected_root_dir(root_dir)
  return not not (root_dir(vim.api.nvim_buf_get_name(0), vim.api.nvim_get_current_buf()))
end

local deno_root_dir = nvim_lsp.util.root_pattern("deno.json", "deno.jsonc", "deps.ts")
local node_root_dir = nvim_lsp.util.root_pattern("package.json", "node_modules")
local is_deno_proj = detected_root_dir(deno_root_dir)
local is_node_proj = not is_deno_proj

local enhance_server_opts = {
  ["sumneko_lua"] = function(opts)
    opts.settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
          path = runtime_path,
        },
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
        },
        telemetry = {
          enable = false,
        },
      },
    }
  end,
  ["jsonls"] = function(opts)
    opts.filetypes = { "json", "jsonc" }
    opts.settings = {
      json = {
        -- Schemas https://www.schemastore.org
        schemas = {
          {
            fileMatch = { "package.json" },
            url = "https://json.schemastore.org/package.json",
          },
          {
            fileMatch = { "tsconfig*.json" },
            url = "https://json.schemastore.org/tsconfig.json",
          },
          {
            fileMatch = {
              ".prettierrc",
              ".prettierrc.json",
              "prettier.config.json",
            },
            url = "https://json.schemastore.org/prettierrc.json",
          },
          {
            fileMatch = { ".eslintrc", ".eslintrc.json" },
            url = "https://json.schemastore.org/eslintrc.json",
          },
          {
            fileMatch = { ".babelrc", ".babelrc.json", "babel.config.json" },
            url = "https://json.schemastore.org/babelrc.json",
          },
          {
            fileMatch = { "lerna.json" },
            url = "https://json.schemastore.org/lerna.json",
          },
          {
            fileMatch = { "now.json", "vercel.json" },
            url = "https://json.schemastore.org/now.json",
          },
          {
            fileMatch = {
              ".stylelintrc",
              ".stylelintrc.json",
              "stylelint.config.json",
            },
            url = "http://json.schemastore.org/stylelintrc.json",
          },
        },
      },
    }
  end,
  ["tsserver"] = function(opts)
    opts.autostart = is_node_proj
    if is_node_proj then
      opts.root_dir = node_root_dir
      opts.init_options = { lint = true, unstable = true }
      opts.on_attach = function(client, bufnr)
        client.resolved_capabilities.document_formatting = false
        on_attach(client, bufnr)
      end
    end
  end,
  ["eslint"] = function(opts)
    opts.autostart = is_node_proj
    if is_node_proj then
      opts.root_dir = node_root_dir
      opts.init_options = { lint = true, unstable = true }
      opts.on_attach = function(client, bufnr)
        client.resolved_capabilities.document_formatting = false
        on_attach(client, bufnr)
      end
    end
  end,
  ["denols"] = function(opts)
    opts.autostart = is_deno_proj
    if is_deno_proj then
      opts.root_dir = deno_root_dir
      opts.init_options = { lint = true, unstable = true }
    end
  end,
}

lsp_installer.on_server_ready(function(server)
  local opts = {
    on_attach = on_attach,
    capabilities = capabilities,
  }

  if enhance_server_opts[server.name] then
    enhance_server_opts[server.name](opts)
  end

  server:setup(opts)
end)

lsp_installer.settings({
  ui = {
    icons = {
      server_installed = "✓",
      server_pending = "➜",
      server_uninstalled = "✗",
    },
  },
})

vim.opt.completeopt = "menu,menuone,noselect"

-- Setup nvim-cmp.
local cmp = require("cmp")

cmp.setup({
  snippet = {
    -- REQUIRED - you must specify a snippet engine
    expand = function(args)
      vim.fn["vsnip#anonymous"](args.body)
    end,
  },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    -- ["<Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = false }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    ["<Tab>"] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end,
    ["<S-Tab>"] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end,
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "vsnip" },
    { name = "buffer" },
    { name = "path" },
    { name = "nvim_lsp_signature_help" },
    { name = "emoji" },
    { name = "calc" },
    { name = "treesitter" },
  }, {
    { name = "buffer" },
  }),
})

local lspkind = require("lspkind")
cmp.setup({
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol_text", -- show only symbol annotations
      maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
    }),
  },
})

-- null-ls
local sources = { nullls.builtins.completion.spell }

-- Prettier for Node.js
if is_node_proj then
  table.insert(sources, nullls.builtins.formatting.prettier)
end

nullls.setup({
  sources = sources,
})

-- flutter-tools
require("flutter-tools").setup({
  ui = {
    notification_style = 'plugin'
  },
  widget_guides = {
    enabled = true,
  },
  lsp = {
    color = {
      enabled = true,
      background = true,
      virtual_text = false,
    },
    on_attach = on_attach,
    capabilities = capabilities
  }
})
