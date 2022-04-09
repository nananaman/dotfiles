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

opt.shell = "/bin/bash"
cmd('let $SHELL="/bin/bash"')
g.fzf_preview_command = "bat --color=always --plain {-1}"
g.fzf_preview_lines_command = "bat --color=always --plain --number"
map("n", ",f", ":<C-u>CocCommand fzf-preview.GitFiles<CR>", { silent = true })
map("n", ",b", ":<C-u>CocCommand fzf-preview.Buffers<CR>", { silent = true })
map("n", ",h", ":<C-u>CocCommand fzf-preview.ProjectMruFiles<CR>", { silent = true })
map("n", ",l", ":<C-u>CocCommand fzf-preview.Lines<CR>", { silent = true })
map("n", ",g", ":<C-u>CocCommand fzf-preview.ProjectGrep<Space>")
