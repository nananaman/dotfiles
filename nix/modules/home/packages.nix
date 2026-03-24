{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Shell
    zsh
    sheldon
    atuin

    # Search & file utilities
    fzf
    ripgrep
    fd

    # File viewers
    lsd
    bat

    # VCS
    git
    git-lfs
    gh
    ghq
    lazygit
    delta

    # Development
    go
    deno
    neovim

    # Other
    silicon
    mise
  ];
}
