# Codex hooks

`hooks.json` is the declarative source of truth for Codex hooks.

`herdr-agent-state.sh` is vendored from `herdr integration install codex` at the Herdr version pinned in `flake.lock`.
When updating Herdr, generate the integration in a temporary home directory and replace this file with the generated script.

`herdr-auto-title.py` is not vendored here. Home Manager installs it directly from the `herdr-auto-title` Flake input pinned in `flake.lock`.
