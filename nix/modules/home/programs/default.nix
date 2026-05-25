{
  config,
  dotfilesDir,
  ...
}:
{
  imports = [
    ./git.nix
    ./starship.nix
    (import ./claude-code.nix { inherit config dotfilesDir; })
    (import ./codex.nix { inherit config dotfilesDir; })
    (import ./pi.nix { inherit config dotfilesDir; })
  ];
}
