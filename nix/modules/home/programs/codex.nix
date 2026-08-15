{
  pkgs,
  config,
  dotfilesDir,
  herdrAutoTitleInput,
  ...
}:
{
  home.packages = [ pkgs.python3 ];

  home.file = {
    ".codex/hooks.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/codex/hooks.json";
      force = true;
    };

    ".codex/hooks/herdr-auto-title.py" = {
      source = "${herdrAutoTitleInput}/herdr_auto_title.py";
      executable = true;
    };

    ".codex/herdr-agent-state.sh" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/codex/herdr-agent-state.sh";
      force = true;
    };
  };
}
