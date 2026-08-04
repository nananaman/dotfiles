#!/usr/bin/env bash

set -euo pipefail

# Arrange: Codexからexternal editorを開いた環境を再現する。
# Act: Markdownを開き、plugin初期化が完了するまで待つ。
output="$({
  NONO_CAP_FILE=/tmp/nono-test-cap \
    nvim --headless README.md '+sleep 1500m' '+messages' '+qa'
} 2>&1)"

# Assert: sandbox内では外部downloaderを起動せず、既存pluginだけで起動を完了する。
if rg -q \
  'EPERM|Falling back to Lua implementation|Error during download|Downloading tree-sitter' \
  <<<"$output"; then
  printf '%s\n' "$output" >&2
  exit 1
fi
