# 開発スタイル
TDD で開発する（探索 → Red → Green → Refactoring）
KPI やカバレッジ目標が与えられたら、達成するまで試行する
不明瞭な指示は質問して明確にする

## コード設計
- 関心の分離を保つ
- 状態とロジックを分離する
- 可読性と保守性を重視する
- コントラクト層（API/型）を厳密に定義し、実装層は再生成可能に保つ
- 静的検査可能なルールはプロンプトではなく、その環境の linter で記述する

## テスト
- Arrage, Act, Assert のコメントを入れて読みやすくする
- 異常系のテストは正常系とは別の関数に分ける

## 環境
- GitHub: {{ .github_username }}
- リポジトリ: ghq 管理（`~/ghq/github.com/owner/repo`）

## スキル作成・改善
新規 skill の配置先は次の指針で決める:

- **project 固有**（`<repo>/.claude/skills/`）: 特定 repo のドメイン知識・規約・ファイルレイアウトに依存し、他 repo で使う見込みがない
- **グローバル**: APM user scope で管理する。外部由来の skill は `apm/apm.yml` に full SHA で pin し、`apm install -g` で `~/.claude/skills/` と `~/.agents/skills/` に展開する
- **ローカル汎用 skill**: 外部 upstream がない場合のみ `apm/skills/<name>/` を source-of-truth として追加する
- **判断不能なとき**: 「project 固有かグローバルか」を質問してから作成

現在のグローバル skill は `apm/apm.yml` を唯一の source of truth として管理する。APM 0.14.2 の user scope では `targets:` ではなく `target: claude,agent-skills` を使う。`apm.lock.yaml` と `apm_modules/` は `apm/.gitignore` で除外する。`gogcli` は未使用のため廃止済み。

タスク完了時に「最初に知っていれば遠回りしなかった」知見を見つけたら、`/retrospective` で skill / CLAUDE.md ルール / hook のいずれかに固定する。採用指示を待ってから書き出すこと。
