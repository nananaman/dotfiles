-- keymaps

local opts = { noremap = true, silent = true }

for k, v in pairs({
  ["<Leader>t"] = "<CMD>TestNearest<CR>",
  ["<Leader>T"] = "<CMD>TestFile<CR>",
  -- ["<Leader>a"] = "<CMD>TestSuite<CR>",
  ["<Leader>tl"] = "<CMD>TestLast<CR>",
  ["<Leader>g"] = "<CMD>TestVisit<CR><Esc>",
  ["<Leader>b"] = "<CMD>lua require('dap').toggle_breakpoint()<CR>",
  ["<Leader>l"] = ":lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>",
  ["<Leader>td"] = ":lua require('dap-go').debug_test()<CR>",
  -- dap-ui key map
  ["<Leader>d"] = ":lua require'dapui'.toggle()<CR>",
  ["<F5>"] = ":lua require'dap'.continue()<CR>"
}) do
  vim.api.nvim_set_keymap("", k, v, opts)
end

require('dap').listeners.before['event_initialized']['custom'] = function(session, body)
  require('dapui').open()
end

-- require('dap').listeners.before['event_terminated']['custom'] = function(session, body)
--   require('dapui').close()
-- end

require('dap-go').setup()
require("dapui").setup()

vim.g['test#strategy'] = {
  nearest = "dap"
}

vim.api.nvim_exec([[
function! EchoStrategy(cmd)
  echo 'It works! Command for running tests: ' . a:cmd
  " let g:vim_test_last_command = a:cmd
  " lua Dap.strategy()
endfunction

let g:test#custom_strategies = {'dap': function('vim_test_strategy')}
]], false)

Dap = {}
Dap.vim_test_strategy = {
  go = function(cmd)
    local test_func = string.match(cmd, "-run '([^ ]+)'")
    local path = string.match(cmd, "[^ ]+$")
    path = string.gsub(path, "/%.%.%.", "")
    configuration = {
      type = "go",
      name = "nvim-dap strategy",
      request = "launch",
      mode = "test",
      program = path,
      args = {},
    }
    if test_func then
      table.insert(configuration.args, "-test.run")
      table.insert(configuration.args, test_func)
    end
    if path == nil or path == "." then
      configuration.program = "./"
    end
    return configuration
  end,
}
function Dap.strategy()
  local cmd = vim.g.vim_test_last_command
  local filetype = vim.bo.filetype
  local f = Dap.vim_test_strategy[filetype]
  if not f then
    print("This filetype is not supported.")
    return
  end
  configuration = f(cmd)
  require 'dap'.run(configuration)
end
