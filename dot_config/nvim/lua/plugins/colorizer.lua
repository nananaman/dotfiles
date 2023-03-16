return {
  'norcalli/nvim-colorizer.lua',
  config = function()
    require("colorizer").setup({ "css", "javascript", "html", "dart", "vue", "lua", "vim" })
  end
}
