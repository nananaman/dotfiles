{ pkgs, herdrPackage, ... }:
let
  python = pkgs.python313Packages;

  azure-ai-inference = python.buildPythonPackage rec {
    pname = "azure-ai-inference";
    version = "1.0.0b9";
    pyproject = true;

    src = python.fetchPypi {
      pname = "azure_ai_inference";
      inherit version;
      hash = "sha256-H+tJa9hLAe4mkb78BDWPol18NE2CiOmTZEOIWa181aQ=";
    };

    build-system = [ python.setuptools ];

    dependencies = with python; [
      azure-core
      isodate
      typing-extensions
    ];

    pythonImportsCheck = [ "azure.ai.inference" ];
  };

  llm-github-models = python.buildPythonPackage rec {
    pname = "llm-github-models";
    version = "0.18.0";
    pyproject = true;

    src = python.fetchPypi {
      pname = "llm_github_models";
      inherit version;
      hash = "sha256-t3iqb6Q+U+yzuGj8+YdbwOdgp3Sh+tduqQeiaVgqIEM=";
    };

    build-system = [ python.setuptools ];

    dependencies = with python; [
      aiohttp
      azure-ai-inference
      llm
    ];

    pythonImportsCheck = [ "llm_github_models" ];
  };

  secretlint = pkgs.buildNpmPackage {
    pname = "dotfiles-secretlint";
    version = "0.0.0";
    src = ../../..;
    npmDepsHash = "sha256-1sVrc0S6G0p+ZWhFXFechDAMGy259J6Ziy8I427Hgks=";
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib/dotfiles-secretlint
      cp -R node_modules package.json package-lock.json $out/lib/dotfiles-secretlint/
      ln -s $out/lib/dotfiles-secretlint/node_modules/.bin/secretlint $out/bin/secretlint

      runHook postInstall
    '';
  };

  omp-cli = import ../../../nix/packages/omp-cli { inherit pkgs; };
  nono-cli =
    let
      version = "0.68.0";
      artifacts = {
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          hash = "sha256-vECYLyarOAIG4ek8rMmJjQwxtdiGP+Xt1CsXzhhGXQQ=";
        };
        x86_64-linux = {
          target = "x86_64-unknown-linux-gnu";
          hash = "sha256-enD79VQjP9X5ZzrNuAZTS1FAE3RgSH0Nhq9JrShsn6o=";
        };
      };
      artifact = artifacts.${pkgs.stdenv.hostPlatform.system};
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "nono";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://github.com/nolabs-ai/nono/releases/download/v${version}/nono-v${version}-${artifact.target}.tar.gz";
        inherit (artifact) hash;
      };

      sourceRoot = ".";

      installPhase = ''
        runHook preInstall

        install -Dm755 nono $out/bin/nono

        runHook postInstall
      '';

      meta = {
        description = "Capability-based sandbox shell for AI agents with OS-enforced isolation";
        homepage = "https://nono.sh";
        license = pkgs.lib.licenses.asl20;
        mainProgram = "nono";
        platforms = builtins.attrNames artifacts;
      };
    };

  canonicalize-herdr-socket = ''
    if [ -n "''${HERDR_SOCKET_PATH:-}" ]; then
      herdr_socket_dir="''${HERDR_SOCKET_PATH%/*}"
      herdr_socket_name="''${HERDR_SOCKET_PATH##*/}"
      if canonical_herdr_socket_dir="$(cd -P -- "$herdr_socket_dir" 2>/dev/null && pwd -P)"; then
        export HERDR_SOCKET_PATH="$canonical_herdr_socket_dir/$herdr_socket_name"
      fi
    fi
  '';

  codex-sandboxed = pkgs.writeShellScriptBin "codex" ''
    ${canonicalize-herdr-socket}
    codex_bin=""
    old_ifs="$IFS"
    IFS=:
    for bin_dir in $PATH; do
      candidate="$bin_dir/codex"
      if [ -x "$candidate" ] && [ ! "$candidate" -ef "$0" ]; then
        codex_bin="$candidate"
        break
      fi
    done
    IFS="$old_ifs"
    if [ -z "$codex_bin" ]; then
      echo "codex: raw executable not found on PATH" >&2
      exit 127
    fi
    if [ -n "''${NONO_CAP_FILE:-}" ]; then
      exec "$codex_bin" --sandbox danger-full-access --ask-for-approval never "$@"
    fi
    HERDR_AGENT=codex exec ${nono-cli}/bin/nono run --silent --profile "$HOME/.config/nono/profiles/chouge-codex.json" --allow-cwd -- \
      "$codex_bin" --sandbox danger-full-access --ask-for-approval never "$@"
  '';

  claude-sandboxed = pkgs.writeShellScriptBin "claude" ''
    ${canonicalize-herdr-socket}
    claude_bin="$HOME/.local/bin/claude"
    if [ ! -x "$claude_bin" ]; then
      echo "claude: raw executable not found: $claude_bin" >&2
      exit 127
    fi
    if [ -n "''${NONO_CAP_FILE:-}" ]; then
      exec "$claude_bin" "$@"
    fi
    HERDR_AGENT=claude exec ${nono-cli}/bin/nono run --silent --profile "$HOME/.config/nono/profiles/chouge-claude.json" --allow-cwd -- \
      "$claude_bin" --dangerously-skip-permissions "$@"
  '';

  pi-sandboxed = pkgs.writeShellScriptBin "pi" ''
    ${canonicalize-herdr-socket}
    pi_bin="$HOME/.vite-plus/bin/pi"
    if [ ! -x "$pi_bin" ]; then
      echo "pi: raw executable not found: $pi_bin" >&2
      exit 127
    fi
    if [ -n "''${NONO_CAP_FILE:-}" ]; then
      exec "$pi_bin" "$@"
    fi
    HERDR_AGENT=pi exec ${nono-cli}/bin/nono run --silent --profile "$HOME/.config/nono/profiles/chouge-pi.json" --allow-cwd -- "$pi_bin" "$@"
  '';

  agent-wrappers = pkgs.symlinkJoin {
    name = "sandboxed-agent-wrappers";
    paths = [
      codex-sandboxed
      claude-sandboxed
      pi-sandboxed
    ];
  };

  apm-cli = python.buildPythonApplication rec {
    pname = "apm-cli";
    version = "0.14.2";
    pyproject = true;

    src = python.fetchPypi {
      pname = "apm_cli";
      inherit version;
      hash = "sha256-VuuhiLhsfOe8eqkzJ4YNLRFvZUAygYZ/HmU2Vhhif+E=";
    };

    build-system = [ python.setuptools ];

    dependencies = with python; [
      click
      colorama
      filelock
      gitpython
      llm
      llm-github-models
      python-frontmatter
      pyyaml
      requests
      rich
      rich-click
      ruamel-yaml
      toml
      watchdog
      websockets
    ];

    pythonImportsCheck = [ "apm_cli" ];
  };
in
{
  home.sessionVariables = {
    RTK_TELEMETRY_DISABLED = "1";
  };

  home.file.".local/share/nono-agent-wrappers".source = "${agent-wrappers}/bin";

  home.packages = with pkgs; [
    # Shell
    zsh
    sheldon
    atuin

    # Search & file utilities
    fzf
    ripgrep
    fd

    # File viewers
    lsd
    bat

    # VCS
    git
    git-lfs
    gh
    ghq
    lazygit

    # Development
    go
    deno
    stdenv.cc
    nixfmt
    neovim
    tree-sitter
    secretlint
    apm-cli
    omp-cli
    herdrPackage
    rtk
    sandbox-runtime
    nono-cli
    agent-wrappers
    tirith

    # Cloud
    google-cloud-sdk

    # Other
    silicon
    mise
  ];
}
