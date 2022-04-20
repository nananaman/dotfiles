-- util functions
local function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map("n", "so", "<C-u>HopChar1<CR>")
map("n", "st", "<C-u>HopChar2<CR>")
map("n", "sl", "<Cmd>HopLine<CR>")
map("n", "sw", "<Cmd>HopWord<CR>")
