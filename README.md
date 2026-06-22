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

## Pre-push secretlint

Home Manager installs a global `secretlint` command, links the default config to
`~/.config/secretlint/.secretlintrc.json`, and configures Git's global
`core.hooksPath` to `~/.config/git/hooks`. The managed `pre-push` hook runs
`secretlint` in every repository and uses a repository-local `.secretlintrc*`
when present.

The hook checks files in the ref range being pushed. For a new branch with no
upstream, it scans all tracked files. Emergency bypass: `git push --no-verify`.

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
apm/                       # Global agent skills managed by APM
agents/                    # Global agent instructions
claude/                    # Claude Code settings
codex/                     # Codex CLI instructions
sandbox-exec/              # macOS sandbox profiles
```
