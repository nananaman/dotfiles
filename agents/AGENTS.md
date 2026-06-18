# グローバル Agent 指示

## コミュニケーション
- 常に日本語で対話する
- Always respond in Japanese, even when the prompt, tool output, or reviewed content is written in English.
- PR title / body / reviewer 向け説明は、ユーザーから別指定がない限り日本語で書く
- Write PR titles, PR descriptions, and reviewer-facing explanations in Japanese unless the user explicitly asks for another language.
- 不明瞭な指示は質問して明確にする
- project の `AGENTS.md` や `CLAUDE.md` がある場合は、その追加指示も尊重する

## 開発スタイル
- TDD で開発する（探索 → Red → Green → Refactoring）
- KPI やカバレッジ目標が与えられたら、達成するまで試行する

## コード設計
- 関心の分離を保つ
- 状態とロジックを分離する
- 可読性と保守性を重視する
- コントラクト層（API/型）を厳密に定義し、実装層は再生成可能に保つ
- 静的検査可能なルールはプロンプトではなく、その環境の linter で記述する
- コメントは必要な箇所にのみ付け、自明なことは書かない

## テスト
- Arrange, Act, Assert のコメントを入れて読みやすくする
- 異常系のテストは正常系とは別の関数に分ける

## 環境
- GitHub: {{ .github_username }}
- リポジトリ: ghq 管理（`~/ghq/github.com/owner/repo`）

## スキル作成・改善
新規 skill の配置先は次の指針で決める:

- **project 固有**（`<repo>/.claude/skills/`）: 特定 repo のドメイン知識・規約・ファイルレイアウトに依存し、他 repo で使う見込みがない
- **グローバル**: APM user scope で管理する。外部由来・自作汎用 skill は `apm/apm.yml` に full SHA で pin し、`apm install -g` で `~/.claude/skills/` と `~/.agents/skills/` に展開する
- **自作汎用 skill**: `nananaman/skills` を source-of-truth として追加し、dotfiles の `apm/apm.yml` から `nananaman/skills/<path>#<full-sha>` で参照する
- **判断不能なとき**: 「project 固有かグローバルか」を質問してから作成

現在のグローバル skill は `apm/apm.yml` を唯一の source of truth として管理する。APM 0.14.2 の user scope では `targets:` ではなく `target: claude,agent-skills` を使う。`apm.lock.yaml` と `apm_modules/` は `apm/.gitignore` で除外する。`gogcli` は未使用のため廃止済み。

タスク完了時に「最初に知っていれば遠回りしなかった」知見を見つけたら、`/retrospective` で skill / CLAUDE.md ルール / hook のいずれかに固定する。採用指示を待ってから書き出すこと。
