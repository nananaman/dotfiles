return {
  { "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui" },
      { "leoluz/nvim-dap-go" },
      { "theHamsta/nvim-dap-virtual-text" },
      { "vim-test/vim-test" },
    },
    config = function()
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
    end },
  { "rcarriga/nvim-dap-ui", config = function()
    require("dapui").setup()
  end },
  { "leoluz/nvim-dap-go", config = function()
    require('dap-go').setup()
  end },
  { "theHamsta/nvim-dap-virtual-text", config = function()
    require("nvim-dap-virtual-text").setup()
  end },
}
