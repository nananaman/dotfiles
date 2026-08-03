{
  pkgs,
  config,
  lib,
  helpers,
  dotfilesDir,
  herdrPackage,
  hunkInput,
  codexCliPackage,
  ...
}:
{
  imports = [
    (import ./packages.nix {
      inherit
        pkgs
        herdrPackage
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
        herdrPackage
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
