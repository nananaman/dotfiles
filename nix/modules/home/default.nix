{
  pkgs,
  config,
  lib,
  helpers,
  dotfilesDir,
  ...
}:
{
  imports = [
    ./packages.nix

    (import ./programs {
      inherit
        pkgs
        lib
        config
        dotfilesDir
        helpers
        ;
    })

    (import ./dotfiles.nix {
      inherit
        pkgs
        lib
        config
        dotfilesDir
        helpers
        ;
    })
  ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
