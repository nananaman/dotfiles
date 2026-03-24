return {
  name = "chezmoi apply",
  builder = function()
    return {
      cmd = { "zsh", "-c", "chezmoi apply && aerospace reload-config" },
      components = { "default" },
    }
  end,
  condition = {
    dir = "~/.local/share/chezmoi/",
  },
}
