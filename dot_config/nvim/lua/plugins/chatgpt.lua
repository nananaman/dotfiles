return {
  "jackMort/ChatGPT.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim"
  },
  config = function()
    require("chatgpt").setup({
      keymaps = {
        close = { "<C-c>" },
        submit = "<C-s>",
        yank_last = "<C-y>",
        yank_last_code = "<C-k>",
        scroll_up = "<C-u>",
        scroll_down = "<C-d>",
        toggle_settings = "<C-o>",
        new_session = "<C-n>",
        cycle_windows = "<Tab>",
        -- in the Sessions pane
        select_session = "<Space>",
        rename_session = "r",
        delete_session = "d",
      },
    })
  end,
}
