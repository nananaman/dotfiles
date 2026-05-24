{
  description = "chouge's dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      darwinUsername = "juntawatanabe";
      darwinHomedir = "/Users/${darwinUsername}";
      darwinDotfilesDir = "${darwinHomedir}/ghq/github.com/chouge/dotfiles";

      wslUsername = "chouge";
      wslHomedir = "/home/${wslUsername}";
      wslDotfilesDir = "${wslHomedir}/ghq/github.com/nananaman/dotfiles";

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (import ./nix/overlays/default.nix)
          ];
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        { system, ... }:
        let
          pkgs = mkPkgs system;
          isDarwin = system == "aarch64-darwin";
          configName = if isDarwin then darwinUsername else wslUsername;
          buildTarget =
            if isDarwin then
              "darwinConfigurations.${configName}.system"
            else
              "homeConfigurations.${configName}.activationPackage";
          homeManager = home-manager.packages.${system}.home-manager;
        in
        {
          formatter = pkgs.nixfmt;

          apps = {
            build = {
              type = "app";
              program = toString (
                pkgs.writeShellScript "nix-build-config" ''
                  set -e
                  echo "Building ${buildTarget}..."
                  nix build .#${buildTarget}
                  echo "Build successful! Run 'nix run .#switch' to apply."
                ''
              );
            };

            switch = {
              type = "app";
              program = toString (
                pkgs.writeShellScript "nix-switch-config" (
                  if isDarwin then
                    ''
                      set -eo pipefail
                      echo "Building and switching to darwin configuration..."
                      sudo nix run nix-darwin -- switch --flake .#${configName}
                      echo "Done!"
                    ''
                  else
                    ''
                      set -eo pipefail
                      echo "Building and switching to home-manager configuration..."
                      ${homeManager}/bin/home-manager switch --flake .#${configName}
                      echo "Done!"
                    ''
                )
              );
            };

            update = {
              type = "app";
              program = toString (
                pkgs.writeShellScript "flake-update" ''
                  set -e
                  echo "Updating flake.lock..."
                  nix flake update
                  echo "Done! Run 'nix run .#switch' to apply changes."
                ''
              );
            };
          };
        };

      flake =
        let
          darwinSystem = "aarch64-darwin";
          darwinPkgs = mkPkgs darwinSystem;
        in
        {
          darwinConfigurations.${darwinUsername} = nix-darwin.lib.darwinSystem {
            system = darwinSystem;

            modules = [
              (import ./nix/modules/darwin/system.nix {
                pkgs = darwinPkgs;
                inherit (darwinPkgs) lib;
                username = darwinUsername;
                homedir = darwinHomedir;
              })

              home-manager.darwinModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "hm-backup";
                  users.${darwinUsername} =
                    {
                      pkgs,
                      config,
                      lib,
                      ...
                    }:
                    let
                      helpers = import ./nix/modules/lib/helpers { inherit lib; };
                      dotfilesDir = darwinDotfilesDir;
                    in
                    {
                      imports = [
                        (import ./nix/modules/home {
                          inherit
                            pkgs
                            config
                            lib
                            helpers
                            dotfilesDir
                            ;
                        })
                      ];
                    };
                };
              }
            ];
          };

          homeConfigurations.${wslUsername} = home-manager.lib.homeManagerConfiguration {
            pkgs = mkPkgs "x86_64-linux";
            modules = [
              (
                {
                  pkgs,
                  config,
                  lib,
                  ...
                }:
                let
                  helpers = import ./nix/modules/lib/helpers { inherit lib; };
                  dotfilesDir = wslDotfilesDir;
                in
                {
                  imports = [
                    (import ./nix/modules/home {
                      inherit
                        pkgs
                        config
                        lib
                        helpers
                        dotfilesDir
                        ;
                    })
                  ];

                  home.username = wslUsername;
                  home.homeDirectory = wslHomedir;
                  targets.genericLinux.enable = true;
                }
              )
            ];
          };
        };
    };
}
