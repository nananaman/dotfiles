#!/usr/bin/env bash

set -euo pipefail

selector="nix/scripts/select-darwin-configuration.sh"
darwin_configurations=(juntawatanabe chouge)

test_each_supported_macos_user_selects_its_matching_configuration() {
  local username
  local actual

  for username in juntawatanabe chouge; do
    # Arrange: 対応対象のmacOSユーザー名を明示して、実PCの状態から隔離する。
    # Act: switchとbuildが共有するconfiguration選択処理を実行する。
    actual="$(bash "$selector" "$username" "${darwin_configurations[@]}")"

    # Assert: PCごとのユーザー名と同名のFlake configurationが選択される。
    [[ "$actual" == "$username" ]]
  done
}

test_unknown_macos_user_is_rejected() {
  # Arrange: Flakeに定義されていないmacOSユーザー名を指定する。
  # Act & Assert: 誤ったユーザー向け構成へfallbackせず失敗する。
  if bash "$selector" unknown-user "${darwin_configurations[@]}" >/dev/null 2>&1; then
    return 1
  fi
}

test_distributed_zsh_config_does_not_depend_on_a_literal_home_directory() {
  # Arrange: Home Managerが両方のmacOSユーザーへ配布するzsh設定を対象にする。
  # Act & Assert: macOSまたはLinux固有のliteralなhome directoryが残っていないことを確認する。
  if grep -En '/(Users|home)/[^/[:space:]]+/' zsh/zshrc; then
    return 1
  fi
}

test_each_supported_macos_user_selects_its_matching_configuration
test_unknown_macos_user_is_rejected
test_distributed_zsh_config_does_not_depend_on_a_literal_home_directory
