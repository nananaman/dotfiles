{
  lib,
  config,
  dotfilesDir,
  helpers,
  ...
}:
let
  inherit (config.home) homeDirectory;
  inherit (config.xdg) configHome;
in
{
  home.activation.linkDotfiles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${helpers.activation.mkLinkForce}

    link_force "${dotfilesDir}/nvim" "${configHome}/nvim"

    link_force "${dotfilesDir}/zsh/zshrc" "${homeDirectory}/.zshrc"
    link_force "${dotfilesDir}/zsh/sheldon" "${configHome}/sheldon"

    link_force "${dotfilesDir}/ghostty" "${configHome}/ghostty"
    $DRY_RUN_CMD mkdir -p "${homeDirectory}/Library/Application Support/com.mitchellh.ghostty"
    link_force "${dotfilesDir}/ghostty/config" "${homeDirectory}/Library/Application Support/com.mitchellh.ghostty/config"

    link_force "${dotfilesDir}/aerospace/aerospace.toml" "${homeDirectory}/.aerospace.toml"
    link_force "${dotfilesDir}/lazygit" "${configHome}/lazygit"
    link_force "${dotfilesDir}/cspell" "${configHome}/cspell"
    link_force "${dotfilesDir}/sql-formatter" "${configHome}/sql-formatter"
    link_force "${dotfilesDir}/stylua.toml" "${configHome}/stylua.toml"

    $DRY_RUN_CMD mkdir -p "${configHome}/git"
    link_force "${dotfilesDir}/git/ignore" "${configHome}/git/ignore"

    # sandbox-exec (substitute @HOME@ at activation time)
    $DRY_RUN_CMD mkdir -p "${configHome}/sandbox-exec"
    $DRY_RUN_CMD sed "s|@HOME@|${homeDirectory}|g" \
      "${dotfilesDir}/sandbox-exec/agent.sb.in" \
      > "${configHome}/sandbox-exec/agent.sb"
  '';
}
