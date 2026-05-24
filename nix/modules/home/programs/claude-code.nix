{ config, dotfilesDir, ... }:
let
  claudeDir = "${dotfilesDir}/claude";
in
{
  home.file = {
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/settings.json";
    ".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/CLAUDE.md";
    ".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/commands";
  };
}
