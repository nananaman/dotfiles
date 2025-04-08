return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "folke/lsp-colors.nvim",
      "davidmh/cspell.nvim",
      "hrsh7th/vim-vsnip",
      "hrsh7th/vim-vsnip-integ",
      "rafamadriz/friendly-snippets",
      "onsails/lspkind-nvim",
      "nvimtools/none-ls.nvim",
      "akinsho/flutter-tools.nvim",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local null_ls = require("null-ls")
      -- local capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())
      local mason = require("mason")

      -- Use LspAttach autocommand to only map the following keys
      -- after the language server attaches to the current buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          -- Enable completion triggered by <c-x><c-o>
          vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

          -- Buffer local mappings.
          -- See `:help vim.lsp.*` for documentation on any of the below functions
          local opts = { buffer = ev.buf }
          -- vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          -- vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          -- vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
          -- vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
          -- vim.keymap.set("n", "<space>wl", function()
          --   print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          -- end, opts)
          -- vim.keymap.set("n", "gD", vim.lsp.buf.type_definition, opts)
          -- vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
          -- vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
          -- vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "<space>f", function()
            vim.lsp.buf.format({ async = true })
          end, opts)
        end,
      })

      mason.setup({
        ui = {
          icons = {
            server_installed = "✓",
            server_pending = "➜",
            server_uninstalled = "✗",
          },
        },
      })

      -- Mappings.
      local map_opts = { noremap = true, silent = true }
      -- vim.api.nvim_set_keymap("n", "<space>e", "<cmd>lua vim.diagnostic.open_float()<CR>", map_opts)
      vim.api.nvim_set_keymap("n", "<space>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", map_opts)

      local runtime_path = vim.split(package.path, ";")
      table.insert(runtime_path, "lua/?.lua")
      table.insert(runtime_path, "lua/?/init.lua")

      local is_node_proj = lspconfig.util.root_pattern("package.json")

      local mason_lspconfig = require("mason-lspconfig")
      mason_lspconfig.setup_handlers({
        function(server_name)
          local opts = {
            -- on_attach = on_attach,
            capabilities = capabilities,
          }

          lspconfig[server_name].setup(opts)
        end,
        ["lua_ls"] = function()
          lspconfig.lua_ls.setup({
            settings = {
              Lua = {
                runtime = { version = "LuaJIT", path = runtime_path },
                diagnostics = { globals = { "vim" } },
                workspace = { library = vim.api.nvim_get_runtime_file("", true) },
                telemetry = { enable = false },
              },
            },
          })
        end,
        ["jsonls"] = function()
          lspconfig.jsonls.setup({
            filetypes = { "json", "jsonc" },
            settings = {
              json = {
                -- Schemas https://www.schemastore.org
                schemas = {
                  { fileMatch = { "package.json" },   url = "https://json.schemastore.org/package.json" },
                  { fileMatch = { "tsconfig*.json" }, url = "https://json.schemastore.org/tsconfig.json" },
                  {
                    fileMatch = { ".prettierrc", ".prettierrc.json", "prettier.config.json" },
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
                  { fileMatch = { "lerna.json" },              url = "https://json.schemastore.org/lerna.json" },
                  { fileMatch = { "now.json", "vercel.json" }, url = "https://json.schemastore.org/now.json" },
                  {
                    fileMatch = { ".stylelintrc", ".stylelintrc.json", "stylelint.config.json" },
                    url = "http://json.schemastore.org/stylelintrc.json",
                  },
                },
              },
            },
          })
        end,
        ["ts_ls"] = function()
          lspconfig.ts_ls.setup({
            root_dir = lspconfig.util.root_pattern("package.json"),
            init_options = { lint = true, unstable = true },
            -- on_attach = function(client, bufnr)
            --   client.resolved_capabilities.document_formatting = false
            --   on_attach(client, bufnr)
            -- end,
          })
        end,
        ["eslint"] = function()
          lspconfig.eslint.setup({
            root_dir = lspconfig.util.root_pattern("package.json"),
            init_options = { lint = true, unstable = true },
            -- on_attach = function(client, bufnr)
            --   client.resolved_capabilities.document_formatting = false
            --   on_attach(client, bufnr)
            -- end,
          })
        end,
        ["denols"] = function()
          lspconfig.denols.setup({
            root_dir = lspconfig.util.root_pattern("deno.json"),
            init_options = {
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
            },
          })
        end,
        ["pyright"] = function()
          lspconfig.pyright.setup({
            settings = {
              python = {
                venvPath = ".",
                pythonPath = "./.venv/bin/python",
                analysis = {
                  extraPaths = { "." },
                },
              },
            },
          })
        end,
      })

      lspconfig.nushell.setup({
        cmd = { "nu", "--lsp" },
        filetypes = { "nu" },
      })
      lspconfig.sourcekit.setup({
        cmd = { "sourcekit-lsp" },
        filetypes = { "swift", "c", "cpp", "objective-c", "objective-cpp" },
        root_dir = lspconfig.util.root_pattern(
          "buildServer.json",
          "*.xcodeproj",
          "*.xcworkspace",
          ".git",
          "compile_commands.json",
          "Package.swift"
        ),
      })

      vim.opt.completeopt = "menu,menuone,noselect"
      local lspkind = require("lspkind")
      lspkind.init({
        symbol_map = {
          Supermaven = "",
        },
      })

      -- null-ls
      local sources = {
        null_ls.builtins.completion.spell,
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.sql_formatter.with({
          extra_args = { "--config", vim.fn.getenv("HOME") .. "/.config/sql-formatter/config.json" },
        }),
        null_ls.builtins.formatting.black,
        null_ls.builtins.formatting.isort,
        null_ls.builtins.formatting.golines.with({
          extra_args = { "-max-len", "120" },
        }),
      }

      -- cspell
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

      local cspell = require("cspell")

      table.insert(
        sources,
        cspell.diagnostics.with({
          diagnostics_postprocess = function(diagnostic)
            -- レベルをWARNに変更（デフォルトはERROR）
            diagnostic.severity = vim.diagnostic.severity["WARN"]
          end,
          condition = function()
            -- cspellが実行できるときのみ有効
            return vim.fn.executable("cspell") > 0
          end,
          -- 起動時に設定ファイル読み込み
          extra_args = { "--config", vim.fn.getenv("HOME") .. "/.config/cspell/cspell.json" },
        })
      )
      table.insert(sources, cspell.code_actions)

      -- Prettier for Node.js
      if is_node_proj then
        table.insert(sources, null_ls.builtins.formatting.prettier)
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
          -- capabilities = capabilities,
        },
      })
    end,
  },
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
  { "folke/lsp-colors.nvim" },
  {
    "glepnir/lspsaga.nvim",
    event = "LspAttach",
    dependencies = {
      { "nvim-tree/nvim-web-devicons" },
      --Please make sure you install markdown and markdown_inline parser
      { "nvim-treesitter/nvim-treesitter" },
    },
    config = function()
      require("lspsaga").setup({})
      local lspsaga = require("lspsaga")
      lspsaga.setup({})

      local keymap = vim.keymap.set

      -- Code action
      keymap({ "n", "v" }, "<space>ca", "<cmd>Lspsaga code_action<CR>")

      -- Rename all occurrences of the hovered word for the selected files
      keymap("n", "<space>rn", "<cmd>Lspsaga rename ++project<CR>")

      -- Peek definition
      -- You can edit the file containing the definition in the floating window
      -- It also supports open/vsplit/etc operations, do refer to "definition_action_keys"
      -- It also supports tagstack
      -- Use <C-t> to jump back
      keymap("n", "gp", "<cmd>Lspsaga peek_definition<CR>")

      -- Go to definition
      -- keymap("n", "gd", "<cmd>Lspsaga goto_definition<CR>")

      -- Peek type definition
      -- You can edit the file containing the type definition in the floating window
      -- It also supports open/vsplit/etc operations, do refer to "definition_action_keys"
      -- It also supports tagstack
      -- Use <C-t> to jump back
      keymap("n", "gt", "<cmd>Lspsaga peek_type_definition<CR>")

      keymap("n", "gj", "<cmd>Lspsaga diagnostic_jump_next<CR>")
      keymap("n", "gk", "<cmd>Lspsaga diagnostic_jump_prev<CR>")

      -- Show line diagnostics
      -- You can pass argument ++unfocus to
      -- unfocus the show_line_diagnostics floating window
      keymap("n", "<space>sl", "<cmd>Lspsaga show_line_diagnostics<CR>")

      -- Show buffer diagnostics
      keymap("n", "<space>sb", "<cmd>Lspsaga show_buf_diagnostics<CR>")

      -- Show workspace diagnostics
      keymap("n", "<space>sw", "<cmd>Lspsaga show_workspace_diagnostics<CR>")

      -- Show cursor diagnostics
      keymap("n", "<space>sc", "<cmd>Lspsaga show_cursor_diagnostics<CR>")

      -- If you want to keep the hover window in the top right hand corner,
      -- you can pass the ++keep argument
      -- Note that if you use hover with ++keep, pressing this key again will
      -- close the hover window. If you want to jump to the hover window
      -- you should use the wincmd command "<C-w>w"
      -- keymap("n", "K", "<cmd>Lspsaga hover_doc ++keep<CR>")
    end,
  },
  { "hrsh7th/vim-vsnip" },
  { "hrsh7th/vim-vsnip-integ" },
  { "rafamadriz/friendly-snippets" },
  { "onsails/lspkind-nvim" },
  {
    "jay-babu/mason-null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "nvimtools/none-ls.nvim",
    },
    config = function()
      require("mason-null-ls").setup({
        ensure_installed = nil,
        automatic_installation = true,
      })
    end,
  },
}
