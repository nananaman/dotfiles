{ config, dotfilesDir, ... }:
let
  piAgentDir = "${dotfilesDir}/pi/agent";
in
{
  home.file = {
    ".pi/agent/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/agents/AGENTS.md";
    ".pi/agent/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/settings.json";
  };
}
