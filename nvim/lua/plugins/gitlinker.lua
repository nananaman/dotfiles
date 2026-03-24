return {
  "linrongbin16/gitlinker.nvim",
  cmd = "GitLink",
  opts = {},
  keys = {
    { "gy", "<cmd>GitLink<cr>", mode = { "n", "v" }, desc = "Yank git link" },
    { "gY", "<cmd>GitLink!<cr>", mode = { "n", "v" }, desc = "Open git link" },
  },
}
