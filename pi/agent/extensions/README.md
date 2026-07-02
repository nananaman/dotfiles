# Pi extensions

## `herdr-agent-state.ts`

`herdr-agent-state.ts` is vendored from `herdr integration install pi` so that
home-manager can install the Herdr Pi integration reproducibly.

Update flow:

1. Save the current vendored file.
2. Run `herdr integration install pi` to generate the upstream integration.
3. Copy `~/.pi/agent/extensions/herdr-agent-state.ts` to
   `pi/agent/extensions/herdr-agent-state.ts`.
4. Apply `herdr-agent-state.local.patch` from this directory.
5. Regenerate `herdr-agent-state.local.patch` by diffing the generated upstream
   file against the patched vendored file.
6. Run the Pi extension smoke check and `nix run .#build`.

The patch records dotfiles-owned behavior, including socket validation,
TUI-session guarding, and shutdown state cleanup. Keep new local behavior in the
patch so future Herdr updates have an explicit review boundary.
