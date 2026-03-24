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
      username = "juntawatanabe";
      homedir = "/Users/${username}";
      dotfilesDir = "${homedir}/ghq/github.com/chouge/dotfiles";

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
      systems = [ "aarch64-darwin" ];

      perSystem =
        { system, ... }:
        let
          pkgs = mkPkgs system;
          hostname = username;
        in
        {
          apps = {
            build = {
              type = "app";
              program = toString (
                pkgs.writeShellScript "darwin-build" ''
                  set -e
                  echo "Building darwin configuration..."
                  nix build .#darwinConfigurations.${hostname}.system
                  echo "Build successful! Run 'nix run .#switch' to apply."
                ''
              );
            };

            switch = {
              type = "app";
              program = toString (
                pkgs.writeShellScript "darwin-switch" ''
                  set -eo pipefail
                  echo "Building and switching to darwin configuration..."
                  sudo nix run nix-darwin -- switch --flake .#${hostname}
                  echo "Done!"
                ''
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
          darwinConfigurations.${username} = nix-darwin.lib.darwinSystem {
            system = darwinSystem;

            modules = [
              (import ./nix/modules/darwin/system.nix {
                pkgs = darwinPkgs;
                inherit (darwinPkgs) lib;
                inherit username homedir;
              })

              home-manager.darwinModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "hm-backup";
                  users.${username} =
                    {
                      pkgs,
                      config,
                      lib,
                      ...
                    }:
                    let
                      helpers = import ./nix/modules/lib/helpers { inherit lib; };
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
        };
    };
}
