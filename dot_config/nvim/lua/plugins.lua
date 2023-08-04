local opts = { noremap = true, silent = true }

for k, v in pairs({
  ["|"] = "<CMD>vsplit<CR>",
  ["-"] = "<CMD>split<CR>",
  ["<Esc><Esc>"] = "<CMD>nohlsearch<CR><Esc>",
}) do
  vim.api.nvim_set_keymap("", k, v, opts)
end

return {
  -- 依存
  { "nvim-lua/plenary.nvim" },
  { "vim-denops/denops.vim" },
  { "MunifTanjim/nui.nvim" },
  { "rcarriga/nvim-notify" },

  -- 操作
  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
      })
    end,
  },
  { "terryma/vim-expand-region" },
  { "tpope/vim-repeat" },

  -- 移動
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    -- stylua: ignore
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- 見た目
  { "machakann/vim-highlightedyank" },
  {
    "folke/todo-comments.nvim",
    config = function()
      require("todo-comments").setup()
    end,
  },
  {
    "kevinhwang91/nvim-hlslens",
    config = function()
      require("hlslens").setup()
    end,
  },

  {
    "dstein64/vim-startuptime",
    -- lazy-load on a command
    cmd = "StartupTime",
  },

  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },

  -- TypeScript
  { "windwp/nvim-ts-autotag" },

  -- Flutter
  {
    "akinsho/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },

  -- Go
  { "golang/vscode-go" },
}
