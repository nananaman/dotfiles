---
description: 直近タスクの気付きを skill / CLAUDE.md ルール / hook に固定する振り返り
---

直近のタスクから「最初に知っていれば遠回りしなかった」知見を抽出し、skill・CLAUDE.md ルール・hook のいずれかに固定する。

`retrospective-codify` skill を Skill tool で起動し、その手順に従う。

## 引数

`$ARGUMENTS` — 任意。指定があれば棚卸し対象をその記述に絞る（例: "git 操作まわりだけ"）。省略時は直近タスク全体。

## 手順

1. `retrospective-codify` skill を Skill tool で起動する。
2. skill のワークフローに従い、失敗⇄成功の対応付けと気付きの言語化を行う。
3. 重複チェック後、提案フォーマットでユーザーに提示する。
4. 採用指示を受けてから書き出す。承認なしに artifact を生成しない。
