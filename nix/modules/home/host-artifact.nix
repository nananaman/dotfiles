{
  pkgs,
  lib,
  config,
  ...
}:
let
  home = config.home.homeDirectory;
  skillRoot = "${home}/.agents/skills/host-artifact";
  serviceRoot = "${home}/.local/share/host-artifact";
  publishRoot = "${serviceRoot}/public";
  stateRoot = "${home}/.local/state/host-artifact";
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.activation.prepareHostArtifactDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg publishRoot}
      $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg stateRoot}
    '';

    home.activation.prepareHostArtifactRuntime =
      lib.hm.dag.entryAfter [ "prepareHostArtifactDirectories" ]
        ''
          if [ ! -f ${lib.escapeShellArg "${skillRoot}/bun.lock"} ]; then
            echo "host-artifact: run apm install -g before Home Manager activation" >&2
            exit 1
          fi
          (
            cd ${lib.escapeShellArg skillRoot}
            $DRY_RUN_CMD ${pkgs.bun}/bin/bun install --frozen-lockfile --production
          )
        '';

    home.activation.restartHostArtifactService =
      lib.hm.dag.entryAfter [ "prepareHostArtifactRuntime" ]
        ''
          if /bin/launchctl print "gui/$UID/com.nananaman.host-artifact" >/dev/null 2>&1; then
            $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$UID/com.nananaman.host-artifact"
          fi
        '';

    launchd.agents.com-nananaman-host-artifact = {
      enable = true;
      config = {
        Label = "com.nananaman.host-artifact";
        ProgramArguments = [
          "${home}/.local/share/nono-agent-wrappers/host-artifact-server"
        ];
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
        };
        ProcessType = "Background";
        StandardOutPath = "${stateRoot}/host-artifact-stdout.log";
        StandardErrorPath = "${stateRoot}/host-artifact-stderr.log";
      };
    };
  };
}
