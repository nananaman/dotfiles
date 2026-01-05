---
description: 現在の作業内容について PR を作成する
allowed-tools: 
  - Bash(git add:*)
  - Bash(git status:*)
  - Bash(git commit:*)
  - Bash(gh pr:*)
  - Read
  - AskUserQuestion
---

# 概要
現在の作業内容について PR を作成してください。以下の手順に従ってください。

1. 現在の差分を踏まえて新しい branch を作成する
2. 差分を add して commit する
3. `.github/pull_request_template.md` があるか確認する
    1. テンプレート内に選択肢やチェックボックス、記入が必要なセクションなど確認が必要な要素があれば、AskUserQuestion で確認する
4. push して draft で PR を作成する（テンプレートがあればそれに沿う）
5. PR の作成が完了したら `gh pr view --web` を使ってブラウザで表示する

もし差分が無ければ、現在のブランチから main ブランチに向けたPRを作成してください。
