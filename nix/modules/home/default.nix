{
  pkgs,
  config,
  lib,
  helpers,
  dotfilesDir,
  herdrPackage,
  hunkInput,
  ...
}:
{
  imports = [
    (import ./packages.nix { inherit pkgs herdrPackage; })

    (import ./programs {
      inherit
        pkgs
        lib
        config
        dotfilesDir
        helpers
        hunkInput
        ;
    })

    (import ./dotfiles.nix {
      inherit
        pkgs
        lib
        config
        dotfilesDir
        helpers
        herdrPackage
        ;
    })
  ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
