# dotfiles

My dotfiles managed by Nix Flakes + home-manager + nix-darwin.

## Prerequisites

Install [Nix](https://nixos.org/) via [Determinate Systems installer](https://determinate.systems/nix-installer/):

```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

## Usage

```bash
# Build (dry run)
nix run .#build

# Build and apply
nix run .#switch

# Update dependencies
nix run .#update
```

## Structure

```
flake.nix                  # Entry point
nix/
  modules/
    home/                  # Cross-platform (home-manager)
      packages.nix         # CLI tools (fzf, ripgrep, bat, etc.)
      dotfiles.nix         # Symlink management
      programs/            # App configs (git, starship, etc.)
    darwin/                # macOS settings (nix-darwin)
      system.nix           # Dock, Finder, keyboard, Homebrew casks
    lib/helpers/           # Shared utilities
  overlays/                # Custom packages
nvim/                      # Neovim configuration
zsh/                       # Zsh configuration
ghostty/                   # Ghostty terminal configuration
tmux/                      # tmux configuration
aerospace/                 # AeroSpace window manager
lazygit/                   # Lazygit configuration
git/                       # Git config & ignore
claude/                    # Claude Code settings & skills
codex/                     # Codex CLI instructions
sandbox-exec/              # macOS sandbox profiles
```
