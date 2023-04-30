return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<C-l>",
        }
      },
      panel = { enabled = false },
      filetypes = {
        yaml = true,
      },
    },
  },
  {
    "zbirenbaum/copilot-cmp",
    dependencies = "copilot.lua",
    opts = {},
    config = function(_, opts)
      local copilot_cmp = require("copilot_cmp")
      copilot_cmp.setup(opts)
      -- lspkind.lua
      local lspkind = require("lspkind")
      lspkind.init({
        symbol_map = {
          Copilot = "",
        },
      })

      vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
    end,
  },
}
