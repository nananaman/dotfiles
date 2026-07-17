{ config, dotfilesDir, ... }:
let
  piAgentDir = "${dotfilesDir}/pi/agent";
in
{
  home.file = {
    ".pi/agent/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/settings.json";
    ".pi/agent/pi-codex-conversion.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/pi-codex-conversion.json";
      force = true;
    };
    ".pi/agent/extensions/rtk.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/extensions/rtk.ts";
    ".pi/agent/extensions/tirith-guard.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/extensions/tirith-guard.ts";
    ".pi/agent/extensions/herdr-agent-state.ts" = {
      source = config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/extensions/herdr-agent-state.ts";
      force = true;
    };
  };
}
