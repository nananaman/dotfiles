{ pkgs, lib, username, homeDirectory, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # Shell
    zsh

    # Editor
    neovim

    # CLI tools
    fzf
    ripgrep
    bat
    lsd
    delta
    lazygit
    ghq
    starship
    sheldon
    atuin
    jq
    fd
    wget
    silicon

    # Languages & runtimes
    go
    deno
    rustup
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    gcc
  ];

  programs.home-manager.enable = true;
}
