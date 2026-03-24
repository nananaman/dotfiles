{
  pkgs,
  username,
  homedir,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  nix.enable = false; # Determinate Nix が管理

  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  system = {
    stateVersion = 5;
    primaryUser = username;

    defaults = {
      dock = {
        autohide = true;
        show-recents = false;
        tilesize = 45;
        orientation = "bottom";
      };

      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
      };

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        KeyRepeat = 2;
        InitialKeyRepeat = 25;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };

      screencapture = {
        location = "~/Pictures/Screenshots";
        type = "png";
      };
    };
  };

  users.users.${username} = {
    home = homedir;
    shell = pkgs.zsh;
  };

  fonts.packages = with pkgs; [
    hackgen-nf-font
  ];

  homebrew = {
    enable = true;
    onActivation.cleanup = "uninstall";

    taps = [
      "nikitabobko/tap"
    ];

    casks = [
      "ghostty"
      "nikitabobko/tap/aerospace"
    ];
  };
}
