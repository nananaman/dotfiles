return {
  "stevearc/overseer.nvim",
  opts = {},
  config = function()
    require("overseer").setup({
      templates = {
        "builtin",
      },
    })

    local opts = { noremap = true, silent = true }
    vim.api.nvim_set_keymap("n", "<space>or", "<cmd>OverseerRun<CR>", opts)
  end,
}
