{
  pkgs,
  config,
  dotfilesDir,
  herdrAutoTitleInput,
  hunkInput,
  ...
}:
{
  imports = [
    ./git.nix
    (import ./agent-instructions.nix { inherit config dotfilesDir; })
    (import ./codex.nix {
      inherit
        pkgs
        config
        dotfilesDir
        herdrAutoTitleInput
        ;
    })
    (import ./hunk.nix { inherit pkgs hunkInput; })
    ./starship.nix
    (import ./claude-code.nix { inherit config dotfilesDir; })
    (import ./pi.nix { inherit pkgs config dotfilesDir; })
  ];
}
