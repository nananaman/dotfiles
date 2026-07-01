{ pkgs, hunkInput, ... }:
{
  imports = [ hunkInput.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    package = hunkInput.packages.${pkgs.stdenv.hostPlatform.system}.hunk;
    enableGitIntegration = true;

    settings = {
      theme = "auto";
      mode = "auto";
      line_numbers = true;
      wrap_lines = false;
      menu_bar = true;
      agent_notes = true;
    };
  };
}
