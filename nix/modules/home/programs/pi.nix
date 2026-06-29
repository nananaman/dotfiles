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
    ".pi/agent/pi-codex-conversion.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/pi-codex-conversion.json";
      force = true;
    };
    ".pi/agent/extensions/rtk.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/extensions/rtk.ts";
  };
}
