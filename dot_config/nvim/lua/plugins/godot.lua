return {
  "habamax/vim-godot",
  dependencies = {
    "junegunn/fzf",
  },
  config = function()
    vim.g.godot_executable = "/Applications/Godot.app"
    require("lspconfig").gdscript.setup({
      capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities()),
    })

    local ft = vim.api.nvim_buf_get_option(0, "filetype")
    if ft ~= "gdscript" then
      return
    end

    local opts = { buffer = 0 }

    vim.keymap.set("n", "<F4>", ":GodotRunLast<CR>", opts)
    vim.keymap.set("n", "<F5>", ":GodotRun<CR>", opts)
    vim.keymap.set("n", "<F6>", ":GodotRunCurrent<CR>", opts)
    vim.keymap.set("n", "<F7>", ":GodotrunFZF<CR>", opts)
  end,
}
