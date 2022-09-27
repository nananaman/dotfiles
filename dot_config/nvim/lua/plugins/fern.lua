vim.g["fern#renderer"] = "nerdfont"

local opts = { noremap = true, silent = true }

function fern_settings()
  vim.api.nvim_buf_set_keymap(0, "", "p", "<Plug>(fern-action-preview:toggle)", opts)
  vim.api.nvim_buf_set_keymap(0, "", "<C-p>", "<Plug>(fern-action-preview:auto:toggle)", opts)
  vim.api.nvim_buf_set_keymap(0, "", "<C-d>", "<Plug>(fern-action-preview:scroll:down:half)", opts)
  vim.api.nvim_buf_set_keymap(0, "", "<C-u>", "<Plug>(fern-action-preview:scroll:up:half)", opts)
  vim.fn["glyph_palette#apply"]()
end

vim.api.nvim_create_augroup("fern-settings", {})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "fern",
  group = "fern-settings",
  callback = fern_settings,
})
