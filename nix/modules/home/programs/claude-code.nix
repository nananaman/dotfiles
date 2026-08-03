{ config, dotfilesDir, ... }:
let
  claudeDir = "${dotfilesDir}/claude";
in
{
  home.file = {
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/settings.json";
  };
}
