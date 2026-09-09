{
  pkgs,
  codexCliPackage,
  ...
}:
let
  python = pkgs.python313Packages;
  agent-wrapper-dir = ".local/share/nono-agent-wrappers";
  agent-wrapper = import ./agent-wrappers.nix { inherit pkgs; };

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

  # Remove this override once codex-cli-nix includes 0.154.0 or newer.
  codex-package =
    let
      version = "0.154.0";
      hashes = {
        "codex-aarch64-apple-darwin.tar.gz" =
          "344310a0a591c1b192e04feff304321a69907c9498baaac331ca7e16ebcef9d7";
        "codex-code-mode-host-aarch64-apple-darwin.tar.gz" =
          "500ee2a02ea598ae519052e7d7d8e201d1db01986f30c214ef4143645dc86fad";
        "codex-x86_64-unknown-linux-musl.tar.gz" =
          "d7e18b2597ae8f242f5f31ee9e90deef48dbc9edd634d9868fb6435d08c07f02";
        "codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz" =
          "a68df7cca23c6da7cde175677df7de61c73a234add1333a1254b86d641af01f7";
      };
    in
    (codexCliPackage.override {
      fetchurl =
        args:
        let
          asset = builtins.baseNameOf args.url;
        in
        pkgs.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/${asset}";
          sha256 = hashes.${asset};
        };
    }).overrideAttrs
      { inherit version; };

  codex-sandboxed = agent-wrapper.codex {
    codex = "${codex-package}/libexec/codex";
  };

  claude-sandboxed = agent-wrapper.claude { };

  pi-sandboxed = agent-wrapper.pi { };

  container-sandboxed = agent-wrapper.container { container = "/opt/homebrew/bin/container"; };

  agent-wrappers = pkgs.symlinkJoin {
    name = "sandboxed-agent-wrappers";
    paths = [
      codex-sandboxed
      claude-sandboxed
      pi-sandboxed
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
    secretlint
    apm-cli
    omp-cli
    rtk
    sandbox-runtime
    nono-cli
    agent-browser
    agent-wrappers

    # Cloud
    google-cloud-sdk

    # Other
    silicon
    mise
  ];
}
