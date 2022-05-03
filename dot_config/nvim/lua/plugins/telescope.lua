local function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map("n", ",f", ":Telescope find_files<CR>", { silent = true })
map("n", ",b", ":Telescope buffers<CR>", { silent = true })
map("n", ",g", ":Telescope live_grep<CR>")
map("n", ",h", ":Telescope help_tags<CR>")

-- map("n", "gr", ":Telescope lsp_references<CR>")
