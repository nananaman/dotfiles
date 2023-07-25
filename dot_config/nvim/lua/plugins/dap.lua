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
        -- ["<space>t"] = "<CMD>TestNearest<CR>",
        ["<space>T"] = "<CMD>TestFile<CR>",
        -- ["<space>a"] = "<CMD>TestSuite<CR>",
        ["<space>tl"] = "<CMD>TestLast<CR>",
        ["<space>g"] = "<CMD>TestVisit<CR><Esc>",
        ["<space>b"] = "<CMD>lua require('dap').toggle_breakpoint()<CR>",
        -- ["<space>l"] = ":lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>",
        ["<space>td"] = ":lua require('dap-go').debug_test()<CR>",
        -- dap-ui key map
        ["<space>d"] = ":lua require'dapui'.toggle()<CR>",
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
