require("nvim-treesitter.configs").setup({
  highlight = {
    enable = true,
    disable = {},
  },
  autotag = {
    enable = true,
  },
  matchup = {
    enable = true,              -- mandatory, false will disable the whole extension
  },
  auto_install = true,
  -- ensure_installed = "all",
})
