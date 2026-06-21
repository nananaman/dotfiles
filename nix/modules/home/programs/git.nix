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
        email = "36331803+nananaman@users.noreply.github.com";
      };
      credential.helper = "!gh auth git-credential";
      url."https://github.com/".insteadOf = [
        "git@github.com:"
        "ssh://git@github.com/"
      ];
      core.hooksPath = "~/.config/git/hooks";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };
}
