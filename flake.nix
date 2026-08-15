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

    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr-auto-title = {
      url = "github:sh1ma/herdr-auto-title/7e5aeebadac9f04f4b343d206af8f406249c124d";
      flake = false;
    };

    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      nix-darwin,
      home-manager,
      herdr,
      hunk,
      codex-cli-nix,
      ...
    }:
    let
      darwinUsernames = [
        "juntawatanabe"
        "chouge"
      ];

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
          homeManager = home-manager.packages.${system}.home-manager;
        in
        {
          formatter = pkgs.nixfmt;

          apps = {
            build = {
              type = "app";
              program = toString (
                pkgs.writeShellScript "nix-build-config" (
                  if isDarwin then
                    ''
                      set -e
                      config_name="$(${pkgs.bash}/bin/bash ${./nix/scripts/select-darwin-configuration.sh} "$(id -un)" ${pkgs.lib.escapeShellArgs darwinUsernames})"
                      echo "Building darwinConfigurations.$config_name.system..."
                      nix build ".#darwinConfigurations.$config_name.system"
                      echo "Build successful! Run 'nix run .#switch' to apply."
                    ''
                  else
                    ''
                      set -e
                      echo "Building homeConfigurations.${wslUsername}.activationPackage..."
                      nix build .#homeConfigurations.${wslUsername}.activationPackage
                      echo "Build successful! Run 'nix run .#switch' to apply."
                    ''
                )
              );
            };

            switch = {
              type = "app";
              program = toString (
                pkgs.writeShellScript "nix-switch-config" (
                  if isDarwin then
                    ''
                      set -eo pipefail
                      config_name="$(${pkgs.bash}/bin/bash ${./nix/scripts/select-darwin-configuration.sh} "$(id -un)" ${pkgs.lib.escapeShellArgs darwinUsernames})"
                      echo "Building and switching to darwin configuration..."
                      sudo -H nix run nix-darwin -- switch --flake ".#$config_name"
                      echo "Done!"
                    ''
                  else
                    ''
                      set -eo pipefail
                      echo "Building and switching to home-manager configuration..."
                      ${homeManager}/bin/home-manager switch --flake .#${wslUsername}
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
          mkDarwinConfiguration =
            username:
            let
              homedir = "/Users/${username}";
              dotfilesDir = "${homedir}/ghq/github.com/nananaman/dotfiles";
            in
            nix-darwin.lib.darwinSystem {
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
                            herdrPackage = herdr.packages.${pkgs.system}.default;
                            herdrAutoTitleInput = inputs.herdr-auto-title;
                            hunkInput = hunk;
                            codexCliPackage = codex-cli-nix.packages.${pkgs.system}.codex;
                          })
                        ];
                      };
                  };
                }
              ];
            };
        in
        {
          darwinConfigurations = darwinPkgs.lib.genAttrs darwinUsernames mkDarwinConfiguration;

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
                      herdrPackage = herdr.packages.${pkgs.system}.default;
                      herdrAutoTitleInput = inputs.herdr-auto-title;
                      hunkInput = hunk;
                      codexCliPackage = codex-cli-nix.packages.${pkgs.system}.codex;
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
