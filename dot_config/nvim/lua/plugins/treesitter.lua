return { "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate"
  config = function()
    local parser_install_dir = vim.fn.stdpath "data" .. "/treesitter"
    vim.opt.runtimepath:append(parser_install_dir)

    require("nvim-treesitter.configs").setup({
      parser_install_dir = parser_install_dir,
      highlight = {
        enable = true,
        disable = {},
      },
      autotag = {
        enable = true,
      },
      matchup = {
        enable = true, -- mandatory, false will disable the whole extension
      },
      auto_install = true,
      -- ensure_installed = "all",
    })
  end }
