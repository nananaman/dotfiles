return {
  {
    "nvimtools/none-ls.nvim",
    event = "VeryLazy",
    dependencies = {
      "folke/lsp-colors.nvim",
      "davidmh/cspell.nvim",
      "hrsh7th/vim-vsnip",
      "hrsh7th/vim-vsnip-integ",
      "rafamadriz/friendly-snippets",
      "akinsho/flutter-tools.nvim",
    },
    opts = function(_, opts)
      vim.opt.completeopt = "menu,menuone,noselect"

      local null_ls = require("null-ls")

      -- null-ls
      local sources = {
        null_ls.builtins.completion.spell,
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.sql_formatter.with({
          extra_args = { "--config", vim.fn.getenv("HOME") .. "/.config/sql-formatter/config.json" },
        }),
        null_ls.builtins.formatting.black,
        null_ls.builtins.formatting.golines.with({
          extra_args = { "-max-len", "120" },
        }),
      }

      local cspell = require("cspell")

      table.insert(
        sources,
        cspell.diagnostics.with({
          diagnostics_postprocess = function(diagnostic)
            -- レベルをHINTに変更（デフォルトはERROR）
            diagnostic.severity = vim.diagnostic.severity["HINT"]
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

      opts.sources = sources

      -- Prettier for Node.js
      -- local is_node_proj = lspconfig.util.root_pattern("package.json")
      -- if is_node_proj then
      --   table.insert(sources, null_ls.builtins.formatting.prettier)
      -- end

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
  { "folke/lsp-colors.nvim" },
  {
    "glepnir/lspsaga.nvim",
    event = "LspAttach",
    dependencies = {
      { "nvim-tree/nvim-web-devicons" },
      { "nvim-treesitter/nvim-treesitter" },
    },
    config = function()
      require("lspsaga").setup({
        lightbulb = {
          enable = false
        }
      })

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
      "mason-org/mason.nvim",
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
