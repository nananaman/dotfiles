{ config, dotfilesDir, ... }:
{
  xdg.configFile."codex/instructions.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/codex/instructions.md";
}
