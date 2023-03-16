return {
  {
    'nvim-telescope/telescope.nvim', tag = '0.1.1',
    dependencies = {
      'nvim-lua/plenary.nvim',
      "nvim-telescope/telescope-fzf-native.nvim"
    },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          sorting_strategy = "ascending",
          layout_config = { prompt_position = "top" },
          file_ignore_patterns = { "node_modules" },
        },
      })
      require('telescope').load_extension('fzf')
      require("telescope").load_extension("notify")

      local function map(mode, lhs, rhs, opts)
        local options = { noremap = true }
        if opts then
          options = vim.tbl_extend("force", options, opts)
        end
        vim.api.nvim_set_keymap(mode, lhs, rhs, options)
      end

      map("n", ",f", ":Telescope find_files<CR>", { silent = true })
      map("n", ",b", ":Telescope buffers<CR>", { silent = true })
      map("n", ",g", ":Telescope live_grep<CR>", { silent = true })
      map("n", ",h", ":Telescope help_tags<CR>", { silent = true })
      map("n", ",n", ":Telescope notify<CR>", { silent = true })
      map("n", ",d", ":TodoTelescope<CR>", { silent = true, noremap = true })

      -- map("n", "gr", ":Telescope lsp_references<CR>")
    end
  }
}
