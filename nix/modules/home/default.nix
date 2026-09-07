{
  pkgs,
  config,
  lib,
  helpers,
  dotfilesDir,
  hunkInput,
  codexCliPackage,
  ...
}:
{
  imports = [
    (import ./packages.nix {
      inherit
        pkgs
        codexCliPackage
        ;
    })

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
        ;
    })

    (import ./host-artifact.nix {
      inherit
        pkgs
        lib
        config
        ;
    })
  ];

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
