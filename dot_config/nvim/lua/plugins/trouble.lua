return {
  "folke/trouble.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    vim.api.nvim_set_keymap("n", "<space>xx", "<cmd>Trouble<cr>", { silent = true, noremap = true })
    vim.api.nvim_set_keymap("n", "<space>xw", "<cmd>Trouble workspace_diagnostics<cr>",
      { silent = true, noremap = true })
    vim.api.nvim_set_keymap("n", "<space>xd", "<cmd>Trouble document_diagnostics<cr>", { silent = true, noremap = true })
    vim.api.nvim_set_keymap("n", "<space>xl", "<cmd>Trouble loclist<cr>", { silent = true, noremap = true })
    vim.api.nvim_set_keymap("n", "<space>xq", "<cmd>Trouble quickfix<cr>", { silent = true, noremap = true })
    vim.api.nvim_set_keymap("n", "<space>xt", "<cmd>TodoTrouble<cr>", { silent = true, noremap = true })

    vim.api.nvim_set_keymap("n", "gr", "<cmd>Trouble lsp_references<cr>", { silent = true, noremap = true })
    -- vim.api.nvim_set_keymap("n", "gD", "<cmd>Trouble lsp_type_definitions<cr>", { silent = true, noremap = true })
  end
}
