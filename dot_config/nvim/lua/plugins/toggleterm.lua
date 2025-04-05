return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    function _G.set_terminal_keymaps()
      local opts = { noremap = true }
      vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
      -- vim.api.nvim_buf_set_keymap(0, 't', '<C-h>', [[<C-\><C-n><C-W>h]], opts)
      -- vim.api.nvim_buf_set_keymap(0, 't', '<C-j>', [[<C-\><C-n><C-W>j]], opts)
      -- vim.api.nvim_buf_set_keymap(0, 't', '<C-k>', [[<C-\><C-n><C-W>k]], opts)
      -- vim.api.nvim_buf_set_keymap(0, 't', '<C-l>', [[<C-\><C-n><C-W>l]], opts)
    end

    -- if you only want these mappings for toggle term use term://*toggleterm#* instead
    vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

    local float_handler = function(term)
      vim.api.nvim_buf_del_keymap(term.bufnr, "t", "<esc>")
    end

    require("toggleterm").setup({
      open_mapping = [[,t]],
      shade_filetypes = { "none" },
      shade_terminals = false,
      direction = "vertical",
      insert_mappings = false,
      start_in_insert = true,
      float_opts = { border = "rounded", winblend = 3 },
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return math.floor(vim.o.columns * 0.4)
        end
      end,
    })
  end,
}
