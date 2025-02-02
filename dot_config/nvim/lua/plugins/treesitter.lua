return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local configs = require("nvim-treesitter.configs")

    configs.setup({
      parser_install_dir = parser_install_dir,
      highlight = {
        enable = true,
        -- disable = { "make", "env" },
      },
      autotag = {
        enable = true,
      },
      matchup = {
        enable = true, -- mandatory, false will disable the whole extension
      },
      auto_install = true,
      ensure_installed = { "nu" },
    })
  end,
  dependencies = {
    { "nushell/tree-sitter-nu", build = ":TSUpdate nu" },
  },
}
