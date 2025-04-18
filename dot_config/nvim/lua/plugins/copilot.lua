return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    build = ":Copilot auth",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<Tab>",
          accept_word = "<C-e>",
          next = "<C-j>",
          prev = "<C-k>",
        },
      },
      panel = { enabled = false },
      filetypes = {
        yaml = true,
      },
      copilot_model = "gpt-4o-copilot"
    },
  },
}
