{ ... }:
{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "chouge";
        email = "foolawoola@gmail.com";
      };
      core.hooksPath = "~/.config/git/hooks";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };
}
