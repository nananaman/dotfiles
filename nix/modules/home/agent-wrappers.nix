{ pkgs }:
{
  codex =
    { codex }:
    pkgs.writeShellScriptBin "codex" (
      builtins.replaceStrings [ "@CODEX@" ] [ codex ] (builtins.readFile ./codex-wrapper.sh)
    );

  claude = { }: pkgs.writeShellScriptBin "claude" (builtins.readFile ./claude-wrapper.sh);

  pi = { }: pkgs.writeShellScriptBin "pi" (builtins.readFile ./pi-wrapper.sh);

  container =
    { container }:
    pkgs.writeShellScriptBin "container" (
      builtins.replaceStrings [ "@CONTAINER@" ] [ container ] (builtins.readFile ./container-wrapper.sh)
    );
}
