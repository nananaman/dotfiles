return {
  'lewis6991/gitsigns.nvim',
  config = function()
    require('gitsigns').setup({ signcolumn = true, numhl = false, linehl = false, })

    local map_opts = { noremap = true, silent = true }
    vim.api.nvim_set_keymap("n", "<space>gb", "<cmd>Gitsigns blame_line<CR>", map_opts)
  end
}
