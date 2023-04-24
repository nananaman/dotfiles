return {
  "akinsho/bufferline.nvim",
  config = function()
    -- Bufferを<C-o><C-p>で切り替え
    vim.api.nvim_set_keymap("n", "<C-o>", ":BufferLineCyclePrev<CR>", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("n", "<C-p>", ":BufferLineCycleNext<CR>", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("n", "gb", ":BufferLinePick<CR>", { noremap = true, silent = true })

    local groups = require("bufferline.groups")
    require("bufferline").setup({
      options = {
        show_buffer_close_icons = false,
        show_close_icon = false,
        diagnostics = "coc",
        diagnostics_indicator = function(count, level, diagnostics_dict, context)
          local s = " "
          for e, n in pairs(diagnostics_dict) do
            local sym = e == "error" and " " or (e == "warning" and " " or "")
            s = s .. sym .. n
          end
          return s
        end,
        separator_style = { "▎", "▎" },
        groups = {
          options = {
            toggle_hidden_on_enter = true,
          },
          items = {
            groups.builtin.ungrouped,
            {
              highlight = { guisp = "#7E9CD8", gui = "underline" },
              name = "tests",
              icon = "",
              matcher = function(buf)
                return buf.name:match("%_spec") or buf.name:match("%_test")
              end,
            },
            {
              highlight = { guisp = "#98BB6C", gui = "underline" },
              name = "docs",
              matcher = function(buf)
                return buf.name:match("%.md") or buf.name:match("%.txt")
              end,
            },
          },
        },
      },
    })
  end
}
