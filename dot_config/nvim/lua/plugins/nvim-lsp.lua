return {
  { "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "folke/lsp-colors.nvim",
      "glepnir/lspsaga.nvim",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lsp-signature-help",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-emoji",
      "hrsh7th/cmp-calc",
      "f3fora/cmp-spell",
      "hrsh7th/cmp-vsnip",
      "ray-x/cmp-treesitter",
      "hrsh7th/vim-vsnip",
      "hrsh7th/vim-vsnip-integ",
      "rafamadriz/friendly-snippets",
      "onsails/lspkind-nvim",
      "jose-elias-alvarez/null-ls.nvim",
      "akinsho/flutter-tools.nvim",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local null_ls = require("null-ls")
      local capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())
      local mason = require("mason")
      local lspsaga = require("lspsaga")

      mason.setup({
        ui = {
          icons = {
            server_installed = "✓",
            server_pending = "➜",
            server_uninstalled = "✗",
          },
        },
      })

      lspsaga.setup({})

      -- Mappings.
      local map_opts = { noremap = true, silent = true }
      vim.api.nvim_set_keymap("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>", map_opts)
      vim.api.nvim_set_keymap("n", "<space>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", map_opts)

      local on_attach = function(client, bufnr)
        local function buf_set_keymap(...)
          vim.api.nvim_buf_set_keymap(bufnr, ...)
        end

        buf_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.type_definition()<CR>", map_opts)
        -- buf_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", map_opts)
        buf_set_keymap("n", "gd", "<cmd>Lspsaga peek_definition<CR>", map_opts)
        buf_set_keymap("n", "gj", "<cmd>Lspsaga diagnostic_jump_next<CR>", map_opts)
        buf_set_keymap("n", "gk", "<cmd>Lspsaga diagnostic_jump_prev<CR>", map_opts)
        buf_set_keymap("n", "K", "<cmd>Lspsaga hover_doc<CR>", map_opts)
        -- buf_set_keymap("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", map_opts)
        buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", map_opts)
        -- buf_set_keymap("n", "<C-k>", "<cmd>Lspsaga signature_help<CR>", map_opts)
        buf_set_keymap("n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", map_opts)
        buf_set_keymap("n", "<leader>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", map_opts)
        buf_set_keymap("n", "<leader>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", map_opts)
        buf_set_keymap("n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>",
          map_opts)
        buf_set_keymap("n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", map_opts)
        buf_set_keymap("n", "<leader>ac", "<cmd>Lspsaga code_action<CR>", map_opts)
        buf_set_keymap("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", map_opts)
        -- buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", map_opts)
        buf_set_keymap("n", "<leader>f", "<cmd>lua vim.lsp.buf.format { async = true }<CR>", map_opts)
        buf_set_keymap("n", "<leader>o", "<cmd>Lspsaga outline<CR>", map_opts)
      end


      -- vim.keymap.set("n", "<leader>rn", function()
      --   return ":IncRename " .. vim.fn.expand("<cword>")
      -- end, { expr = true })

      local runtime_path = vim.split(package.path, ";")
      table.insert(runtime_path, "lua/?.lua")
      table.insert(runtime_path, "lua/?/init.lua")

      local is_node_proj = lspconfig.util.root_pattern("package.json")
      local is_python_proj = lspconfig.util.root_pattern("pyproject.toml", "Pipfile")

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
          opts.root_dir = lspconfig.util.root_pattern("package.json")
          opts.init_options = { lint = true, unstable = true }
          opts.on_attach = function(client, bufnr)
            client.resolved_capabilities.document_formatting = false
            on_attach(client, bufnr)
          end
        end,
        ["eslint"] = function(opts)
          opts.root_dir = lspconfig.util.root_pattern("package.json")
          opts.init_options = { lint = true, unstable = true }
          opts.on_attach = function(client, bufnr)
            client.resolved_capabilities.document_formatting = false
            on_attach(client, bufnr)
          end
        end,
        ["denols"] = function(opts)
          opts.root_dir = lspconfig.util.root_pattern("deno.json")
          opts.init_options = {
            lint = true,
            unstable = true,
            suggest = {
              imports = {
                hosts = {
                  ["https://deno.land"] = true,
                  ["https://cdn.nest.land"] = true,
                  ["https://crux.land"] = true,
                },
              },
            },
          }
        end,
        ["pyright"] = function(opts)
          opts.settings = {
            python = {
              venvPath = ".",
              pythonPath = "./.venv/bin/python",
              analysis = {
                extraPaths = { "." }
              }
            }
          }
        end,
      }

      local mason_lspconfig = require("mason-lspconfig")
      mason_lspconfig.setup_handlers({
        function(server_name)
          local opts = {
            on_attach = on_attach,
            capabilities = capabilities,
          }

          if enhance_server_opts[server_name] then
            enhance_server_opts[server_name](opts)
          end

          lspconfig[server_name].setup(opts)
        end,
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

      -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' }
        }
      })

      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          {
            name = 'cmdline',
            option = {
              ignore_cmds = { 'Man', '!' }
            }
          }
        })
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
      -- vim辞書がなければダウンロード
      if vim.fn.filereadable("~/.local/share/cspell/vim.txt.gz") ~= 1 then
        local vim_dictionary_url = "https://github.com/iamcco/coc-spell-checker/raw/master/dicts/vim/vim.txt.gz"
        io.popen("curl -fsSLo ~/.local/share/cspell/vim.txt.gz --create-dirs " .. vim_dictionary_url)
      end

      -- ユーザー辞書がなければ作成
      if vim.fn.filereadable("~/.local/share/cspell/user.txt") ~= 1 then
        io.popen("mkdir -p ~/.local/share/cspell")
        io.popen("touch ~/.local/share/cspell/user.txt")
      end

      local sources = {
        null_ls.builtins.completion.spell,
        null_ls.builtins.diagnostics.cspell.with({
          diagnostics_postprocess = function(diagnostic)
            -- レベルをWARNに変更（デフォルトはERROR）
            diagnostic.severity = vim.diagnostic.severity["WARN"]
          end,
          condition = function()
            -- cspellが実行できるときのみ有効
            return vim.fn.executable("cspell") > 0
          end,
          -- 起動時に設定ファイル読み込み
          extra_args = { "--config", "~/.config/cspell/cspell.json" },
        }),
      }

      -- Prettier for Node.js
      if is_node_proj then
        table.insert(sources, null_ls.builtins.formatting.prettier)
      end

      -- Python
      if is_python_proj then
        table.insert(sources, null_ls.builtins.formatting.black)
        table.insert(sources, null_ls.builtins.formatting.isort)
      end

      null_ls.setup({
        sources = sources,
      })

      -- flutter-tools
      require("flutter-tools").setup({
        ui = {
          notification_style = "plugin",
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
          capabilities = capabilities,
        },
      })
    end
  },
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
  { "folke/lsp-colors.nvim" },
  { "glepnir/lspsaga.nvim" },
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-nvim-lsp-signature-help" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-cmdline" },
  { "hrsh7th/cmp-emoji" },
  { "hrsh7th/cmp-calc" },
  { "f3fora/cmp-spell" },
  { "hrsh7th/cmp-vsnip" },
  { "ray-x/cmp-treesitter" },
  { "hrsh7th/vim-vsnip" },
  { "hrsh7th/vim-vsnip-integ" },
  { "rafamadriz/friendly-snippets" },
  { "onsails/lspkind-nvim" },
  { "jose-elias-alvarez/null-ls.nvim" },
}
