{
  pkgs,
  config,
  dotfilesDir,
  hunkInput,
  ...
}:
{
  imports = [
    ./git.nix
    (import ./agent-instructions.nix { inherit config dotfilesDir; })
    (import ./hunk.nix { inherit pkgs hunkInput; })
    ./starship.nix
    (import ./claude-code.nix { inherit config dotfilesDir; })
    (import ./pi.nix { inherit config dotfilesDir; })
  ];
}
