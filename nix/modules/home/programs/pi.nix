{
  pkgs,
  config,
  dotfilesDir,
  ...
}:
let
  piAgentDir = "${dotfilesDir}/pi/agent";
  packageManager = "${pkgs.bun}/bin/bun";
  settings = builtins.fromJSON (builtins.readFile ../../../../pi/agent/settings.json) // {
    npmCommand = [ packageManager ];
  };
  baseProfile = builtins.fromJSON (builtins.readFile ../../../../nono/profiles/chouge-pi.json);
  platformOverrides = baseProfile.platform_overrides or { };
  macos = platformOverrides.macos or { };
  seatbeltRules = macos.unsafe_macos_seatbelt_rules or [ ];
  profile = baseProfile // {
    platform_overrides = platformOverrides // {
      macos = macos // {
        unsafe_macos_seatbelt_rules = seatbeltRules ++ [
          ''(allow process-exec (literal "${packageManager}"))''
        ];
      };
    };
  };
in
{
  home.file = {
    ".pi/agent/settings.json" = {
      text = builtins.toJSON settings;
      force = true;
    };
    ".config/nono/profiles/chouge-pi.json" = {
      text = builtins.toJSON profile;
      force = true;
    };
    ".pi/agent/pi-codex-conversion.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/pi-codex-conversion.json";
      force = true;
    };
    ".pi/agent/extensions/tirith-guard.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/extensions/tirith-guard.ts";
    ".pi/agent/extensions/herdr-agent-state.ts" = {
      source = config.lib.file.mkOutOfStoreSymlink "${piAgentDir}/extensions/herdr-agent-state.ts";
      force = true;
    };
  };
}
