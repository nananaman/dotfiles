require("plugins.telescope")
require("plugins.transparent")
require("plugins.treesitter")
require("plugins.hop")
require("plugins.bufferline")
require("plugins.lualine")
require("plugins.kanagawa")
require("plugins.trouble")

-- aliases
local cmd = vim.cmd -- to execute Vim commands e.g. cmd('pwd')
local fn = vim.fn -- to call Vim functions e.g. fn.bufnr()
local g = vim.g -- a table to access global variables
local opt = vim.opt -- to set options

-- util functions
local function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- /sonictemplate.vim
-- <C-y><C-b>で後方補完
cmd('let g:sonictemplate_vim_template_dir = [ "~/.config/nvim/sonictemplate" ]')

-- Gina.vim設定
map("n", "<leader>gc", ":Gina commit<CR><CR>")
-- map("n", "<leader>ga", ":<C-u>CocCommand fzf-preview.GitActions<CR>")
-- map("n", "<leader>gs", ":<C-u>CocCommand fzf-preview.GitStatus<CR>")

map("n", "<leader>gp", ":Gina push<CR>")
map("n", "<leader>gd", ":Gina diff<CR>")
map("n", "<leader>gl", ":Gina log<CR>")
map("n", "<leader>gb", ":Gina blame<CR>")

-- vim-expand-region設定
map("", "+", "<Plug>(expand_region_expand)", { noremap = false })
map("", "-", "<Plug>(expand_region_shrink)", { noremap = false })

require("colorizer").setup({ "css", "javascript", "html", "dart", "vue", "lua", "vim" })
