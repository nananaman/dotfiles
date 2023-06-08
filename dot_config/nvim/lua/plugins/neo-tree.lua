return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-tree/nvim-web-devicons" }, -- not strictly required, but recommended
      { "MunifTanjim/nui.nvim" },
    },
    config = function()
      require("neo-tree").setup({
        window = {
          mappings = {
            ["<"] = "",
            [">"] = "",
            ["<C-o>"] = "prev_source",
            ["<C-p>"] = "next_source",
          },
        },
        source_selector = {
          winbar = true,
          statusline = true,
        },
      })
      local opts = { noremap = true, silent = true }
      vim.api.nvim_set_keymap("n", "<C-n>", ":Neotree reveal toggle<CR>", opts)
    end,
  },
}
