{ pkgs, ... }:
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
    delta

    # Development
    go
    deno
    clang
    nixfmt
    neovim
    tree-sitter
    secretlint
    apm-cli
    tmux
    rtk
    sandbox-runtime

    # Cloud
    google-cloud-sdk

    # Other
    silicon
    mise
  ];
}
