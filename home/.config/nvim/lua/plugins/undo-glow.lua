return {
  "y3owk1n/undo-glow.nvim",
  version = "*", -- use stable releases
  opts = {},
  keys = {
    {
      "u",
      function()
        require("undo-glow").undo()
      end,
      mode = "n",
      desc = "Undo with highlight",
      noremap = true,
    },
    {
      "<C-r>",
      function()
        require("undo-glow").redo()
      end,
      mode = "n",
      desc = "Redo with highlight",
      noremap = true,
    },
    {
      "p",
      function()
        require("undo-glow").paste_below()
      end,
      mode = "n",
      desc = "Paste below with highlight",
      noremap = true,
    },
    {
      "P",
      function()
        require("undo-glow").paste_above()
      end,
      mode = "n",
      desc = "Paste above with highlight",
      noremap = true,
    },
  },
}
