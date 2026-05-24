{
  pkgs,
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
    ${lib.optionalString pkgs.stdenv.isDarwin ''
      $DRY_RUN_CMD mkdir -p "${homeDirectory}/Library/Application Support/com.mitchellh.ghostty"
      link_force "${dotfilesDir}/ghostty/config" "${homeDirectory}/Library/Application Support/com.mitchellh.ghostty/config"
    ''}

    link_force "${dotfilesDir}/zellij" "${configHome}/zellij"

    ${lib.optionalString pkgs.stdenv.isDarwin ''
      link_force "${dotfilesDir}/aerospace/aerospace.toml" "${homeDirectory}/.aerospace.toml"
    ''}
    link_force "${dotfilesDir}/lazygit" "${configHome}/lazygit"
    link_force "${dotfilesDir}/cspell" "${configHome}/cspell"
    link_force "${dotfilesDir}/sql-formatter" "${configHome}/sql-formatter"
    link_force "${dotfilesDir}/stylua.toml" "${configHome}/stylua.toml"

    link_force "${dotfilesDir}/.apm" "${homeDirectory}/.apm"

    ${lib.optionalString pkgs.stdenv.isLinux ''
      cmd_exe="/mnt/c/Windows/System32/cmd.exe"
      wslpath_exe="/usr/bin/wslpath"
      if [ -x "$cmd_exe" ] && [ -x "$wslpath_exe" ]; then
        win_profile="$(${pkgs.coreutils}/bin/timeout 2s "$cmd_exe" /c 'echo %USERPROFILE%' 2>/dev/null | ${pkgs.coreutils}/bin/tr -d '\r' || true)"
        if [ -n "$win_profile" ] && win_profile="$($wslpath_exe "$win_profile" 2>/dev/null)"; then
          for wt_package in Microsoft.WindowsTerminal_8wekyb3d8bbwe Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe; do
            wt_dir="$win_profile/AppData/Local/Packages/$wt_package/LocalState"
            if [ -d "$wt_dir" ]; then
              $DRY_RUN_CMD cp "${dotfilesDir}/windows-terminal/settings.json" "$wt_dir/settings.json"
            fi
          done
        fi
      fi
    ''}

    $DRY_RUN_CMD mkdir -p "${configHome}/git"
    link_force "${dotfilesDir}/git/ignore" "${configHome}/git/ignore"
  '';
}
