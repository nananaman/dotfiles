# dotfiles

My dotfiles managed by chezmoi

## Installation

```
$ sh -c "$(curl -fsLS chezmoi.io/get)" -- init --apply nananaman
```

## Install Tools

```
$ chezmoi cd && bash ./scripts/init.sh
```

This will install and configure:
- Neovim
- Fish shell
- Nushell
- Wezterm
- Zsh
- Additional tools and fonts

## Configuration Structure

```
dot_config/
  ├── chezmoi/        # chezmoi configuration
  ├── cspell/         # spell checking configuration
  ├── fish/           # fish shell configuration
  ├── ghostty/        # ghostty terminal configuration
  ├── lazygit/        # lazygit configuration
  ├── nushell/        # nushell configuration
  ├── nvim/           # neovim configuration
  ├── sheldon/        # shell plugin manager
  ├── sql-formatter/  # SQL formatter configuration
  └── wezterm/        # wezterm terminal configuration
```

## Managing Dotfiles

```
$ chezmoi diff    # See pending changes
$ chezmoi apply   # Apply changes
$ chezmoi cd      # Navigate to the repository
```
