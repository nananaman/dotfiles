return {
  "nvim-lualine/lualine.nvim",
  config = function()
    require("lualine").setup({
      options = { theme = "kanagawa" },
      sections = {
        lualine_c = {
          {
            "filename",
            file_status = true, -- displays file status (readonly status, modified status)
            path = 1, -- 0 = just filename, 1 = relative path, 2 = absolute path
            shorting_target = 40, -- Shortens path to leave 40 space in the window
            -- for other components. Terrible name any suggestions?
            symbols = {
              modified = "[+]", -- when the file was modified
              readonly = "[-]", -- if the file is not modifiable or readonly
              unnamed = "[No Name]", -- default display name for unnamed buffers
            },
          },
        },
        lualine_z = {
          { require("plugins.codecompanion-components.lualine-component") },
        },
      },
    })
  end,
}
