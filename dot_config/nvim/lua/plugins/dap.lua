-- keymaps

local opts = { noremap = true, silent = true }

for k, v in pairs({
  ["<Leader>t"] = "<CMD>TestNearest<CR>",
  ["<Leader>T"] = "<CMD>TestFile<CR>",
  ["<Leader>a"] = "<CMD>TestSuite<CR>",
  ["<Leader>l"] = "<CMD>TestLast<CR>",
  ["<Leader>g"] = "<CMD>TestVisit<CR><Esc>",
}) do
  vim.api.nvim_set_keymap("", k, v, opts)
end

require('dap-go').setup()
