{ pkgs, username, ... }:

{
  # Nix settings (Determinate manages the daemon)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ username ];
  };

  # System-level packages
  environment.systemPackages = with pkgs; [
    coreutils
  ];

  # macOS system defaults
  security.pam.services.sudo_local.touchIdAuth = true;

  # Homebrew integration for cask apps
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "ghostty"
      "nikitabobko/tap/aerospace"
    ];
  };

  # Used for backwards compatibility
  system.stateVersion = 6;
}
