{ pkgs }:
{
  codex =
    {
      canonicalizeHerdrSocket,
      codex,
    }:
    pkgs.writeShellScriptBin "codex" (
      builtins.replaceStrings
        [ "@CANONICALIZE_HERDR_SOCKET@" "@CODEX@" ]
        [
          canonicalizeHerdrSocket
          codex
        ]
        (builtins.readFile ./codex-wrapper.sh)
    );

  claude =
    { canonicalizeHerdrSocket }:
    pkgs.writeShellScriptBin "claude" (
      builtins.replaceStrings [ "@CANONICALIZE_HERDR_SOCKET@" ] [ canonicalizeHerdrSocket ] (
        builtins.readFile ./claude-wrapper.sh
      )
    );

  pi =
    { canonicalizeHerdrSocket }:
    pkgs.writeShellScriptBin "pi" (
      builtins.replaceStrings [ "@CANONICALIZE_HERDR_SOCKET@" ] [ canonicalizeHerdrSocket ] (
        builtins.readFile ./pi-wrapper.sh
      )
    );

  container =
    { container }:
    pkgs.writeShellScriptBin "container" (
      builtins.replaceStrings [ "@CONTAINER@" ] [ container ] (builtins.readFile ./container-wrapper.sh)
    );
}
