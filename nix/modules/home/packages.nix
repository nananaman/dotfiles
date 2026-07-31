{
  pkgs,
  herdrPackage,
  codexCliPackage,
  ...
}:
let
  python = pkgs.python313Packages;
  agent-wrapper-dir = ".local/share/nono-agent-wrappers";

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

  codex-nono-guard = pkgs.writeShellScript "codex-nono-guard" ''
    if [ -z "''${NONO_CAP_FILE:-}" ]; then
      echo "codex: nono capability was not injected" >&2
      exit 1
    fi
    exec "$@"
  '';

  codex-sandboxed = pkgs.writeShellScriptBin "codex" ''
    ${canonicalize-herdr-socket}
    export CODEX_EXECUTABLE_PATH="$HOME/${agent-wrapper-dir}/codex"
    export DISABLE_AUTOUPDATER=1
    if [ -n "''${NONO_CAP_FILE:-}" ]; then
      exec ${codexCliPackage}/bin/codex-raw --sandbox danger-full-access --ask-for-approval never "$@"
    fi
    HERDR_AGENT=codex exec ${nono-cli}/bin/nono run --silent \
      --profile "$HOME/.config/nono/profiles/chouge-codex.jsonc" --allow-cwd -- \
      ${codex-nono-guard} \
      ${codexCliPackage}/bin/codex-raw --sandbox danger-full-access --ask-for-approval never "$@"
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
    HERDR_AGENT=claude exec ${nono-cli}/bin/nono run --silent \
      --profile "$HOME/.config/nono/profiles/chouge-claude.jsonc" --allow-cwd -- \
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
    HERDR_AGENT=pi exec ${nono-cli}/bin/nono run --silent \
      --profile "$HOME/.config/nono/profiles/chouge-pi.jsonc" --allow-cwd -- "$pi_bin" "$@"
  '';

  container-sandboxed = pkgs.writeShellScriptBin "container" ''
    # Codex sessionではagent wrapper directoryがnonoのTool Sandbox shimよりPATHの前に置かれる。
    # Homebrew launcherを直接実行するとlibexec/containerが親sandboxに拒否されるため、
    # nonoが生成したshimへ明示的に委譲する。
    if [ -n "''${NONO_TOOL_SANDBOX_SHIM_DIR:-}" ] &&
      [ -x "$NONO_TOOL_SANDBOX_SHIM_DIR/container" ]; then
      exec "$NONO_TOOL_SANDBOX_SHIM_DIR/container" "$@"
    fi
    exec /opt/homebrew/bin/container "$@"
  '';

  host-artifact-service = pkgs.writeShellScriptBin "host-artifact-service" ''
    if [ "$#" -ne 1 ] || [ "$1" != "ensure" ]; then
      echo "usage: host-artifact-service ensure" >&2
      exit 64
    fi

    health_url="http://127.0.0.1:9417/.well-known/host-artifact/health"
    is_expected_health() {
      case "$1" in
        '{"service":"host-artifact","version":1,"status":"ok"}'|'{"service":"host-artifact","version":1,"status":"ok",'*)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
    }
    health_body="$(/usr/bin/curl --fail --silent --show-error --max-time 1 "$health_url" 2>/dev/null || true)"
    if is_expected_health "$health_body"; then
      exit 0
    fi

    /bin/launchctl kickstart -k "gui/$UID/com.nananaman.host-artifact"
    for _attempt in $(/usr/bin/seq 1 20); do
      health_body="$(/usr/bin/curl --fail --silent --show-error --max-time 1 "$health_url" 2>/dev/null || true)"
      if is_expected_health "$health_body"; then
        exit 0
      fi
      /bin/sleep 0.25
    done

    echo "host-artifact-service: service did not become ready" >&2
    exit 1
  '';

  host-artifact = pkgs.writeShellScriptBin "host-artifact" ''
    case "''${1:-}" in
      host)
        if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
          echo "usage: host-artifact host PATH [--tailscale] [--no-reload]" >&2
          exit 64
        fi
        for flag in "''${@:3}"; do
          if [ "$flag" != "--tailscale" ] && [ "$flag" != "--no-reload" ]; then
            echo "usage: host-artifact host PATH [--tailscale] [--no-reload]" >&2
            exit 64
          fi
        done
        ;;
      update)
        if [ "$#" -ne 3 ]; then
          echo "usage: host-artifact update ARTIFACT_ID PATH" >&2
          exit 64
        fi
        ;;
      remove)
        if [ "$#" -ne 2 ]; then
          echo "usage: host-artifact remove ARTIFACT_ID" >&2
          exit 64
        fi
        ;;
      status)
        if [ "$#" -ne 1 ]; then
          echo "usage: host-artifact status" >&2
          exit 64
        fi
        ;;
      *)
        echo "usage: host-artifact <host PATH [--tailscale] [--no-reload] | update ARTIFACT_ID PATH | remove ARTIFACT_ID | status>" >&2
        exit 64
        ;;
    esac

    exec ${pkgs.bun}/bin/bun \
      "$HOME/.agents/skills/host-artifact/src/cli.ts" "$@"
  '';

  host-artifact-server = pkgs.writeShellScriptBin "host-artifact-server" ''
    skill_root="$HOME/.agents/skills/host-artifact"
    tailscale_address_file="$HOME/.local/state/host-artifact/tailscale-address"
    host_artifact_runtime_fingerprint() {
      {
        ${pkgs.findutils}/bin/find "$skill_root/src" -type f -exec ${pkgs.coreutils}/bin/sha256sum {} \;
        for runtime_file in "$skill_root/package.json" "$skill_root/bun.lock"; do
          if [ -f "$runtime_file" ]; then
            ${pkgs.coreutils}/bin/sha256sum "$runtime_file"
          fi
        done
      } | ${pkgs.coreutils}/bin/sort | ${pkgs.coreutils}/bin/sha256sum
    }
    update_tailscale_address() {
      /usr/local/bin/tailscale ip -4 2>/dev/null | /usr/bin/head -n 1 >"$tailscale_address_file.tmp" || true
      /bin/mv -f "$tailscale_address_file.tmp" "$tailscale_address_file"
    }
    runtime_fingerprint="$(host_artifact_runtime_fingerprint)"
    update_tailscale_address
    while /bin/sleep 15; do
      update_tailscale_address
    done &
    tailscale_updater_pid=$!
    ${nono-cli}/bin/nono run --silent \
      --profile "$HOME/.config/nono/profiles/host-artifact-server.jsonc" -- \
      ${pkgs.bun}/bin/bun \
      "$skill_root/src/server-main.ts" \
      --port 9417 \
      --publish-root "$HOME/.local/share/host-artifact/public" \
      --tailscale-address-file "$tailscale_address_file" &
    server_pid=$!

    while /bin/kill -0 "$server_pid" 2>/dev/null; do
      /bin/sleep 2
      if [ "$(host_artifact_runtime_fingerprint)" != "$runtime_fingerprint" ]; then
        /bin/kill -TERM "$server_pid"
        wait "$server_pid" 2>/dev/null || true
        /bin/kill -TERM "$tailscale_updater_pid" 2>/dev/null || true
        exit 75
      fi
    done

    wait "$server_pid"
    server_exit=$?
    /bin/kill -TERM "$tailscale_updater_pid" 2>/dev/null || true
    exit "$server_exit"
  '';

  agent-wrappers = pkgs.symlinkJoin {
    name = "sandboxed-agent-wrappers";
    paths = [
      codex-sandboxed
      claude-sandboxed
      pi-sandboxed
      host-artifact
      host-artifact-service
      host-artifact-server
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ container-sandboxed ];
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
    NVIM_LOG_FILE = "/dev/null";
    RTK_TELEMETRY_DISABLED = "1";
  };

  home.file.${agent-wrapper-dir}.source = "${agent-wrappers}/bin";

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
