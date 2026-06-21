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
    $DRY_RUN_CMD mkdir -p "${configHome}/zsh"
    link_force "${dotfilesDir}/zsh/functions" "${configHome}/zsh/functions"
    link_force "${dotfilesDir}/zsh/sheldon" "${configHome}/sheldon"

    link_force "${dotfilesDir}/ghostty" "${configHome}/ghostty"
    ${lib.optionalString pkgs.stdenv.isDarwin ''
      $DRY_RUN_CMD mkdir -p "${homeDirectory}/Library/Application Support/com.mitchellh.ghostty"
      link_force "${dotfilesDir}/ghostty/config" "${homeDirectory}/Library/Application Support/com.mitchellh.ghostty/config"
    ''}

    if [ "$(readlink "${configHome}/zellij" 2>/dev/null || true)" = "${dotfilesDir}/zellij" ]; then
      $DRY_RUN_CMD rm -f "${configHome}/zellij"
    fi
    link_force "${dotfilesDir}/tmux" "${configHome}/tmux"

    ${lib.optionalString pkgs.stdenv.isDarwin ''
      link_force "${dotfilesDir}/aerospace/aerospace.toml" "${homeDirectory}/.aerospace.toml"
    ''}
    link_force "${dotfilesDir}/lazygit" "${configHome}/lazygit"
    link_force "${dotfilesDir}/cspell" "${configHome}/cspell"
    link_force "${dotfilesDir}/sql-formatter" "${configHome}/sql-formatter"
    link_force "${dotfilesDir}/stylua.toml" "${configHome}/stylua.toml"
    link_force "${dotfilesDir}/srt" "${configHome}/srt"

    link_force "${dotfilesDir}/apm" "${homeDirectory}/.apm"
    $DRY_RUN_CMD mkdir -p "${homeDirectory}/.claude" "${homeDirectory}/.agents"
    $DRY_RUN_CMD mkdir -p "${dotfilesDir}/apm/claude-skills" "${dotfilesDir}/apm/agent-skills"
    link_force "${dotfilesDir}/apm/claude-skills" "${homeDirectory}/.claude/skills"
    link_force "${dotfilesDir}/apm/agent-skills" "${homeDirectory}/.agents/skills"

    ${lib.optionalString pkgs.stdenv.isLinux ''
      cmd_exe="/mnt/c/Windows/System32/cmd.exe"
      powershell_exe="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
      wslpath_exe="/usr/bin/wslpath"
      if [ -x "$cmd_exe" ] && [ -x "$wslpath_exe" ]; then
        win_profile="$(${pkgs.coreutils}/bin/timeout 2s "$cmd_exe" /c 'echo %USERPROFILE%' 2>/dev/null | ${pkgs.coreutils}/bin/tr -d '\r' || true)"
        if [ -n "$win_profile" ] && win_profile="$($wslpath_exe "$win_profile" 2>/dev/null)"; then
          win_fonts_dir="$win_profile/AppData/Local/Microsoft/Windows/Fonts"
          $DRY_RUN_CMD mkdir -p "$win_fonts_dir"
          $DRY_RUN_CMD cp -f ${pkgs.hackgen-nf-font}/share/fonts/hackgen-nf/HackGenConsoleNF-Regular.ttf "$win_fonts_dir/"
          $DRY_RUN_CMD cp -f ${pkgs.hackgen-nf-font}/share/fonts/hackgen-nf/HackGenConsoleNF-Bold.ttf "$win_fonts_dir/"
          $DRY_RUN_CMD cp -f ${pkgs.hackgen-nf-font}/share/fonts/hackgen-nf/HackGen35ConsoleNF-Regular.ttf "$win_fonts_dir/"
          $DRY_RUN_CMD cp -f ${pkgs.hackgen-nf-font}/share/fonts/hackgen-nf/HackGen35ConsoleNF-Bold.ttf "$win_fonts_dir/"

          if [ -x "$powershell_exe" ] && [ -z "''${DRY_RUN_CMD:-}" ]; then
            "$powershell_exe" -NoProfile -ExecutionPolicy Bypass -Command '
              $ErrorActionPreference = "Stop"
              $fontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
              New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
              $fontsKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
              New-Item -Force -Path $fontsKey | Out-Null

              $entries = @(
                @{ File = "HackGenConsoleNF-Regular.ttf"; Name = "HackGen Console NF (TrueType)" },
                @{ File = "HackGenConsoleNF-Bold.ttf"; Name = "HackGen Console NF Bold (TrueType)" },
                @{ File = "HackGen35ConsoleNF-Regular.ttf"; Name = "HackGen35 Console NF (TrueType)" },
                @{ File = "HackGen35ConsoleNF-Bold.ttf"; Name = "HackGen35 Console NF Bold (TrueType)" }
              )
              foreach ($entry in $entries) {
                $fontPath = Join-Path $fontsDir $entry.File
                if (Test-Path $fontPath) {
                  New-ItemProperty -Path $fontsKey -Name $entry.Name -PropertyType String -Value $fontPath -Force | Out-Null
                }
              }
            '
          fi

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
