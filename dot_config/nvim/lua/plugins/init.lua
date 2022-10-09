-- install vim-jetpack
local fn = vim.fn
local jetpackfile = fn.stdpath('data') .. '/site/pack/jetpack/opt/vim-jetpack/plugin/jetpack.vim'
local jetpackurl = 'https://raw.githubusercontent.com/tani/vim-jetpack/master/plugin/jetpack.vim'
if fn.filereadable(jetpackfile) == 0 then
  fn.system('curl -fsSLo ' .. jetpackfile .. ' --create-dirs ' .. jetpackurl)
end

vim.g.jetpack_copy_method = "copy"

vim.cmd("packadd vim-jetpack")
require("jetpack").startup(function(use)
  use({ "tani/vim-jetpack", opt = 1 }) -- bootstrap
  -- 依存
  use({ "nvim-lua/plenary.nvim" })
  use({ "vim-denops/denops.vim" })
  use({ "MunifTanjim/nui.nvim" })
  use({ "rcarriga/nvim-notify" })

  -- 高速化
  use({ "lewis6991/impatient.nvim" })

  use({ "nvim-treesitter/nvim-treesitter" })
  -- fern
  use({ "lambdalisue/fern.vim" })
  use({ "lambdalisue/fern-renderer-nerdfont.vim" })
  use({ "lambdalisue/fern-git-status.vim" })
  use({ "lambdalisue/glyph-palette.vim" })
  use({ "yuki-yano/fern-preview.vim" })

  -- 操作
  use({ "andymass/vim-matchup" })
  use({ "machakann/vim-sandwich" })
  use({ "terryma/vim-expand-region" })
  use({ "tpope/repeat" })
  use({ "tpope/vim-commentary" })
  use({ "rhysd/clever-f.vim" })

  use({ "segeljakt/vim-silicon" })

  -- 見た目
  use({ "lambdalisue/nerdfont.vim" })
  use({ "xiyaowong/nvim-transparent" })
  use({ "rebelot/kanagawa.nvim" })
  use({ "lukas-reineke/indent-blankline.nvim" })
  use({ "akinsho/bufferline.nvim" })
  use({ "nvim-lualine/lualine.nvim" })
  use({ "norcalli/nvim-colorizer.lua" })
  use({ "tkmpypy/chowcho.nvim" })
  use({ "machakann/vim-highlightedyank" })
  use({ "kyazdani42/nvim-web-devicons" })
  use({ "folke/todo-comments.nvim" })
  use({ "kevinhwang91/nvim-hlslens" })

  use({
    "folke/noice.nvim",
    event = "VimEnter",
  })

  use({ "akinsho/toggleterm.nvim" })
  use({ "yuki-yano/fuzzy-motion.vim" })
  use({ "jose-elias-alvarez/null-ls.nvim" })

  use({ "nvim-telescope/telescope.nvim", requires = { { "nvim-lua/plenary.nvim" } } })
  use({ "nvim-telescope/telescope-fzf-native.nvim", requires = { { "nvim-telescope/telescope.nvim" } }, run = "make" })

  use({ "folke/trouble.nvim" })
  use({ "gelguy/wilder.nvim" })

  -- メニュー
  use({
    "goolord/alpha-nvim",
    requires = { "kyazdani42/nvim-web-devicons" },
  })

  -- TypeScript
  use({ "windwp/nvim-ts-autotag" })

  -- LSP
  use({ "neovim/nvim-lspconfig" })
  use({ "williamboman/mason.nvim" })
  use({ "williamboman/mason-lspconfig.nvim" })
  use({ "folke/lsp-colors.nvim" })
  use({ "tami5/lspsaga.nvim" })
  use({ "hrsh7th/nvim-cmp" })
  use({ "hrsh7th/cmp-nvim-lsp" })
  use({ "hrsh7th/cmp-nvim-lsp-signature-help" })
  use({ "hrsh7th/cmp-buffer" })
  use({ "hrsh7th/cmp-path" })
  use({ "hrsh7th/cmp-emoji" })
  use({ "hrsh7th/cmp-calc" })
  use({ "f3fora/cmp-spell" })
  use({ "hrsh7th/cmp-vsnip" })
  use({ "ray-x/cmp-treesitter" })
  use({ "hrsh7th/vim-vsnip" })
  use({ "hrsh7th/vim-vsnip-integ" })
  use({ "rafamadriz/friendly-snippets" })
  use({ "onsails/lspkind-nvim" })
  use({ "windwp/nvim-autopairs" })
  use({ "akinsho/flutter-tools.nvim" })
  use({ "golang/vscode-go" })
  use({ "mfussenegger/nvim-dap" })
  use({ "rcarriga/nvim-dap-ui" })
end)

-- keymaps

local opts = { noremap = true, silent = true }

for k, v in pairs({
  ["<C-n>"] = "<CMD>Fern . -reveal=% -drawer -toggle<CR>",
  ["<C-w>|"] = "<CMD>vsplit<CR>",
  ["<C-w>-"] = "<CMD>split<CR>",
  ["<Space><Space>"] = "<CMD>FuzzyMotion<CR>",
  ["<Esc><Esc>"] = "<CMD>nohlsearch<CR><Esc>",
}) do
  vim.api.nvim_set_keymap("", k, v, opts)
end

-- settings
require("impatient")
require("impatient").enable_profile()

require("plugins.bufferline")
require("plugins.chowcho")
require("plugins.fern")
require("plugins.indent-blankline")
require("plugins.kanagawa")
require("plugins.lualine")
require("plugins.nvim-lsp")
require("plugins.silicon")
require("plugins.telescope")
require("plugins.toggleterm")
require("plugins.transparent")
require("plugins.treesitter")
require("plugins.trouble")
require("plugins.wilder")
require("plugins.alpha")
require("plugins.notify")
require("plugins.noice")
