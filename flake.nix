{
  description = "nananaman's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, determinate, ... }:
    let
      # Detected at eval time with --impure flag
      username = let u = builtins.getEnv "USER"; in if u == "" then "default" else u;
      homeDirectory = builtins.getEnv "HOME";
      system = builtins.currentSystem;

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      isDarwin = pkgs.stdenv.isDarwin;
    in
    {
      # Linux: home-manager standalone
      # Usage: home-manager switch --flake . --impure
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./nix/home.nix ];
        extraSpecialArgs = { inherit username homeDirectory; };
      };

      # macOS: nix-darwin + home-manager module
      # Usage: darwin-rebuild switch --flake . --impure
      darwinConfigurations.${username} = nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          determinate.darwinModules.default
          home-manager.darwinModules.home-manager
          ./nix/darwin.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./nix/home.nix;
            home-manager.extraSpecialArgs = { inherit username homeDirectory; };
          }
        ];
        specialArgs = { inherit username; };
      };
    };
}
