{ pkgs }:
{
  codex =
    {
      canonicalizeHerdrSocket,
      nono,
      codexGuard,
      codex,
    }:
    pkgs.writeShellScriptBin "codex" (
      builtins.replaceStrings
        [ "@CANONICALIZE_HERDR_SOCKET@" "@NONO@" "@CODEX_GUARD@" "@CODEX@" ]
        [
          canonicalizeHerdrSocket
          nono
          codexGuard
          codex
        ]
        (builtins.readFile ./codex-wrapper.sh)
    );

  claude =
    { canonicalizeHerdrSocket, nono }:
    pkgs.writeShellScriptBin "claude" (
      builtins.replaceStrings [ "@CANONICALIZE_HERDR_SOCKET@" "@NONO@" ] [ canonicalizeHerdrSocket nono ]
        (builtins.readFile ./claude-wrapper.sh)
    );

  pi =
    { canonicalizeHerdrSocket, nono }:
    pkgs.writeShellScriptBin "pi" (
      builtins.replaceStrings [ "@CANONICALIZE_HERDR_SOCKET@" "@NONO@" ] [ canonicalizeHerdrSocket nono ]
        (builtins.readFile ./pi-wrapper.sh)
    );

  container =
    { container }:
    pkgs.writeShellScriptBin "container" (
      builtins.replaceStrings [ "@CONTAINER@" ] [ container ] (builtins.readFile ./container-wrapper.sh)
    );
}
