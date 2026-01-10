---
description: リモートで削除されたローカルブランチ([gone]状態)とそのワークツリーをクリーンアップする
allowed-tools:
  - Bash(git branch:*)
  - Bash(git worktree:*)
  - Bash(git rev-parse:*)
  - Bash(echo:*)
  - Bash(grep:*)
  - Bash(sed:*)
  - Bash(awk:*)
---

# 概要
リモートリポジトリで削除されたが、ローカルに残っている `[gone]` 状態のブランチをクリーンアップします。以下の手順に従ってください。

## 実行手順

### 1. ブランチ状態の確認
まず、`git branch -v` でローカルブランチの一覧と `[gone]` ブランチを確認します。

- `[gone]` タグが付いているブランチ = リモートで削除済み
- `+` プレフィックス = ワークツリーが関連付けられている
- `*` プレフィックス = 現在のブランチ

### 2. ワークツリーの確認
`git worktree list` でワークツリーの一覧を取得し、`[gone]` ブランチに関連するワークツリーを特定します。

### 3. クリーンアップの実行

以下のコマンドで `[gone]` ブランチとワークツリーを削除します：

```bash
git branch -v | grep '\[gone\]' | sed 's/^[+* ]//' | awk '{print $1}' | while read branch; do
  echo "ブランチを処理中: $branch"

  # ワークツリーが存在する場合は削除
  worktree=$(git worktree list | grep "\\[$branch\\]" | awk '{print $1}')
  if [ ! -z "$worktree" ] && [ "$worktree" != "$(git rev-parse --show-toplevel)" ]; then
    echo "  ワークツリーを削除: $worktree"
    git worktree remove --force "$worktree"
  fi

  # ブランチを削除
  echo "  ブランチを削除: $branch"
  git branch -D "$branch"
done
```

### 4. 結果の報告

- `[gone]` ブランチが存在した場合：削除されたブランチとワークツリーのリストを報告
- `[gone]` ブランチが存在しない場合：「クリーンアップの必要はありません」と報告

## エラーハンドリング

- ワークツリー削除時は `--force` フラグで強制削除
- ブランチ削除時は `-D` フラグで強制削除
- メインリポジトリのワークツリーは削除しない（`git rev-parse --show-toplevel` で除外）

## 出力メッセージ

すべてのメッセージは日本語で出力してください：

- ブランチ処理開始: `"ブランチを処理中: {branch_name}"`
- ワークツリー削除: `"  ワークツリーを削除: {worktree_path}"`
- ブランチ削除: `"  ブランチを削除: {branch_name}"`
- クリーンアップ不要: `"[gone] ブランチは見つかりませんでした。クリーンアップの必要はありません。"`
