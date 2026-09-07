# Codex hooks

`hooks.json` is not managed here.
Orca owns `~/.codex/hooks.json` as a real file and rewrites it whenever it installs its agent status hooks, so tracking it in this repository only produced churn.

Because `hooks.json` is no longer generated here, the herdr hooks below are only wired up where something else writes them into `~/.codex/hooks.json`.
Orca keeps existing non-Orca entries when it installs, but a fresh machine — or any environment without Orca, such as WSL — gets no herdr wiring.

`herdr-agent-state.sh` is vendored from `herdr integration install codex` at the Herdr version pinned in `flake.lock`.
When updating Herdr, generate the integration in a temporary home directory and replace this file with the generated script.

`herdr-auto-title.py` is not vendored here. Home Manager installs it directly from the `herdr-auto-title` Flake input pinned in `flake.lock`.
