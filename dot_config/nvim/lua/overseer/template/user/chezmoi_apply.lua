return {
  name = "chezmoi apply",
  builder = function()
    return {
      cmd = { "chezmoi", "apply" },
      components = { "default" },
    }
  end,
  condition = {
    dir = "~/.local/share/chezmoi/",
  },
}
