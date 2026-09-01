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

  agent-browser-package =
    let
      version = "0.35.2";
      artifacts = {
        aarch64-darwin = "agent-browser-darwin-arm64";
        x86_64-linux = "agent-browser-linux-musl-x64";
      };
      artifact = artifacts.${pkgs.stdenv.hostPlatform.system};
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "agent-browser";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/agent-browser/-/agent-browser-${version}.tgz";
        hash = "sha256-2FtnQn51E7GzD7+Na34Ksto3ssEmYhNOTgfxLm2SjvU=";
      };

      sourceRoot = "package";

      installPhase = ''
        runHook preInstall

        install -Dm755 "bin/${artifact}" "$out/bin/agent-browser"
        mkdir -p "$out/share/agent-browser"
        cp -R skills skill-data "$out/share/agent-browser/"

        runHook postInstall
      '';

      meta = {
        description = "Browser automation CLI for AI agents";
        homepage = "https://github.com/vercel-labs/agent-browser";
        license = pkgs.lib.licenses.asl20;
        mainProgram = "agent-browser";
        platforms = builtins.attrNames artifacts;
      };
    };
  agent-browser = pkgs.writeShellApplication {
    name = "agent-browser";
    runtimeInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ];
    text = ''
      export AGENT_BROWSER_SKILLS_DIR=${agent-browser-package}/share/agent-browser/skill-data
      ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
        export CFFIXED_USER_HOME="$HOME/.local/state/nono-agent-tools/agent-browser"
        export AGENT_BROWSER_ARGS="''${AGENT_BROWSER_ARGS:+$AGENT_BROWSER_ARGS,}--no-sandbox"
      ''}
      exec ${agent-browser-package}/bin/agent-browser "$@"
    '';
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
      exec ${codexCliPackage}/libexec/codex --sandbox danger-full-access --ask-for-approval never "$@"
    fi
    HERDR_AGENT=codex exec ${nono-cli}/bin/nono run --silent \
      --profile "$HOME/.config/nono/profiles/chouge-codex.jsonc" --allow-cwd -- \
      ${codex-nono-guard} \
      ${codexCliPackage}/libexec/codex --sandbox danger-full-access --ask-for-approval never "$@"
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
    if [ "$#" -eq 1 ]; then
      case "$1" in
        update | upgrade)
          # Native self-update replaces $HOME/.local/bin/claude via a rename, which needs
          # write access to the whole containing directory. Run it outside the sandbox
          # rather than granting that directory-wide write to every sandboxed session.
          # Guarded to exactly one argv so an unquoted prompt beginning with "update"
          # (claude's positional prompt argument) cannot also take this path.
          exec "$claude_bin" "$@"
          ;;
      esac
    fi
    HERDR_AGENT=claude exec ${nono-cli}/bin/nono run --silent \
      --profile "$HOME/.config/nono/profiles/chouge-claude.jsonc" --allow-cwd --allow-launch-services -- \
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
        '{"service":"host-artifact","version":2,"status":"ok"}'|'{"service":"host-artifact","version":2,"status":"ok",'*)
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

  host-artifact = pkgs.writeShellScriptBin "host-artifact" (
    builtins.replaceStrings
      [ "@BUN@" "@CLI@" "@HELPER_PATH@" ]
      [
        "${pkgs.bun}/bin/bun"
        "$HOME/.agents/skills/host-artifact/src/cli.ts"
        (pkgs.lib.makeBinPath [
          host-artifact-service
          host-artifact-tailscale
          host-artifact-workspace
        ])
      ]
      (builtins.readFile ./host-artifact.sh)
  );

  host-artifact-tailscale = pkgs.writeShellScriptBin "host-artifact-tailscale" (
    builtins.replaceStrings
      [ "@TAILSCALE_WRAPPER@" "@TAILSCALE_APP@" "@CURL@" "@JQ@" "@GREP@" "@TR@" ]
      [
        "/usr/local/bin/tailscale"
        "/Applications/Tailscale.app/Contents/MacOS/tailscale"
        "/usr/bin/curl"
        "${pkgs.jq}/bin/jq"
        "/usr/bin/grep"
        "/usr/bin/tr"
      ]
      (builtins.readFile ./host-artifact-tailscale.sh)
  );

  host-artifact-workspace = pkgs.writeShellScriptBin "host-artifact-workspace" (
    builtins.replaceStrings
      [ "@GIT@" "@JQ@" "@SHASUM@" "@SED@" "@TR@" "@CUT@" ]
      [ "/usr/bin/git" "${pkgs.jq}/bin/jq" "/usr/bin/shasum" "/usr/bin/sed" "/usr/bin/tr" "/usr/bin/cut" ]
      (builtins.readFile ./host-artifact-workspace.sh)
  );

  host-artifact-server = pkgs.writeShellScriptBin "host-artifact-server" ''
    skill_root="$HOME/.agents/skills/host-artifact"
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
    runtime_fingerprint="$(host_artifact_runtime_fingerprint)"
    ${nono-cli}/bin/nono run --silent \
      --profile "$HOME/.config/nono/profiles/host-artifact-server.jsonc" -- \
      ${pkgs.bun}/bin/bun \
      "$skill_root/src/server-main.ts" \
      --port 9417 \
      --publish-root "$HOME/.local/share/host-artifact/public" &
    server_pid=$!

    while /bin/kill -0 "$server_pid" 2>/dev/null; do
      /bin/sleep 2
      if [ "$(host_artifact_runtime_fingerprint)" != "$runtime_fingerprint" ]; then
        /bin/kill -TERM "$server_pid"
        wait "$server_pid" 2>/dev/null || true
        exit 75
      fi
    done

    wait "$server_pid"
    server_exit=$?
    exit "$server_exit"
  '';

  agent-wrappers = pkgs.symlinkJoin {
    name = "sandboxed-agent-wrappers";
    paths = [
      codex-sandboxed
      claude-sandboxed
      pi-sandboxed
      host-artifact
      host-artifact-tailscale
      host-artifact-workspace
      host-artifact-service
      host-artifact-server
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ container-sandboxed ];
  };

  apm-cli = python.buildPythonApplication rec {
    pname = "apm-cli";
    version = "0.28.0";
    pyproject = true;

    src = python.fetchPypi {
      pname = "apm_cli";
      inherit version;
      hash = "sha256-82JToQeMU3B82MIagQb3x/LRV5x7cYWE22G9o1P3RSE=";
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
      tomlkit
      truststore
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
    bun
    go
    deno
    stdenv.cc
    nixfmt
    neovim
    tree-sitter
    ast-grep
    secretlint
    apm-cli
    omp-cli
    herdrPackage
    rtk
    sandbox-runtime
    nono-cli
    agent-browser
    agent-wrappers
    tirith

    # Cloud
    google-cloud-sdk

    # Other
    silicon
    mise
  ];
}
