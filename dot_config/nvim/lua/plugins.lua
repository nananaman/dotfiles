local opts = { noremap = true, silent = true }

for k, v in pairs({
  ["<C-w>|"] = "<CMD>vsplit<CR>",
  ["<C-w>-"] = "<CMD>split<CR>",
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
  { "andymass/vim-matchup" },
  { "machakann/vim-sandwich" },
  { "terryma/vim-expand-region" },
  { "tpope/vim-repeat" },
  { "rhysd/clever-f.vim" },

  -- 移動
  {
    "yuki-yano/fuzzy-motion.vim",
    config = function()
      vim.api.nvim_set_keymap("n", "<Space><Space>", ":FuzzyMotion<CR>", opts)
    end
  },

  -- 見た目
  { "machakann/vim-highlightedyank" },
  {
    "folke/todo-comments.nvim",
    config = function()
      require('todo-comments').setup()
    end
  },
  {
    "kevinhwang91/nvim-hlslens",
    config = function()
      require('hlslens').setup()
    end
  },

  {
    "dstein64/vim-startuptime",
    -- lazy-load on a command
    cmd = "StartupTime",
  },

  { "windwp/nvim-autopairs", config = function()
    require("nvim-autopairs").setup {}
  end },

  -- TypeScript
  { "windwp/nvim-ts-autotag" },

  -- Flutter
  { "akinsho/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
  },

  -- Go
  { "golang/vscode-go" },
}
