{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = false; # zshrc で手動で init している
    settings = {
      command_timeout = 2000;
      format = "$all$kubernetes$line_break$character";

      directory.style = "#FFEB3B";

      git_branch = {
        symbol = " ";
        style = "#FFEB3B";
      };

      kubernetes = {
        format = "on [⎈  $context \\($namespace\\)](dimmed green) ";
        disabled = false;
      };

      gcloud.disabled = true;
    };
  };
}
