{ config, dotfilesDir, ... }:
{
  home.file.".pi/agent/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/agents/AGENTS.md";
}
