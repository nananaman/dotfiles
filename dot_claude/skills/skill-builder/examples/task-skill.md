# タスク実行型Skillの例

このファイルは、タスク実行型skillのサンプルです。

## 例1: デプロイ

```yaml
---
name: deploy
description: アプリケーションを本番環境にデプロイ。デプロイ、リリース、本番反映を行う際に使用。
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
context: fork
---

# 本番デプロイ

アプリケーションを本番環境にデプロイします。

## 前提条件の確認

デプロイ前に以下を確認:

!`git status`

ブランチ: `main`
変更: コミット済み
リモート: 同期済み

## デプロイプロセス

### 1. テスト実行

すべてのテストが通過することを確認:

```bash
npm run test
```

テスト失敗時は中断。

### 2. ビルド作成

本番用ビルドを作成:

```bash
npm run build
```

### 3. デプロイ実行

デプロイターゲットにプッシュ:

```bash
git push production main
```

### 4. ヘルスチェック

デプロイ後、エンドポイントの健全性を確認:

```bash
curl -f https://api.example.com/health || echo "Health check failed"
```

## エラーハンドリング

各ステップで失敗した場合:
1. エラーメッセージを表示
2. プロセスを中断
3. ロールバック方法を提示

## 完了

デプロイが成功したら:
- デプロイ時刻を記録
- チームに通知
- モニタリングダッシュボードを確認
```

**特徴**:
- `disable-model-invocation: true`: 手動実行のみ
- `context: fork`: 安全なサブエージェントで実行
- 明確なステップバイステップの指示
- エラーハンドリング含む

## 例2: テストランナー

```yaml
---
name: test-runner
description: プロジェクトのテストスイートを実行し、結果を報告。テスト、テストスイート、ユニットテスト、統合テストを実行する際に使用。
allowed-tools:
  - Bash
  - Read
  - Grep
---

# テストランナー

## テスト種類の確認

実行するテストの種類:

$ARGUMENTS が空の場合: すべてのテスト
$ARGUMENTS[0] = "unit": ユニットテストのみ
$ARGUMENTS[0] = "integration": 統合テストのみ
$ARGUMENTS[0] = "e2e": E2Eテストのみ

## テスト実行

### すべてのテスト

```bash
npm run test
```

### ユニットテスト

```bash
npm run test:unit
```

### 統合テスト

```bash
npm run test:integration
```

### E2Eテスト

```bash
npm run test:e2e
```

## 結果の解析

テスト結果を解析し、以下を報告:
- 合計テスト数
- 成功数
- 失敗数
- カバレッジ

失敗したテストがある場合、詳細を表示。

## カバレッジレポート

カバレッジが80%未満の場合、警告を表示。
```

**特徴**:
- 引数を受け取る（`$ARGUMENTS`）
- 条件分岐
- 結果の解析と報告

## 例3: PR作成

```yaml
---
name: create-pr
description: 現在のブランチからプルリクエストを作成。PR、プルリクエスト、コードレビュー依頼を行う際に使用。
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Grep
  - AskUserQuestion
---

# プルリクエスト作成

## 現在の状態確認

ブランチとコミット状況:

!`git branch --show-current`
!`git log main..HEAD --oneline`

変更されたファイル:

!`git diff main..HEAD --name-only`

## PR情報の収集

以下の情報を質問:
1. PRタイトル
2. 変更の概要
3. レビュアー

## PR作成

GitHub CLIを使用してPRを作成:

```bash
gh pr create \
  --title "$タイトル" \
  --body "$(cat <<EOF
## 概要
$概要

## 変更内容
!`git diff main..HEAD --stat`

## テスト
- [ ] ユニットテスト追加
- [ ] 手動テスト完了

## チェックリスト
- [ ] コードレビュー
- [ ] CI/CD通過
- [ ] ドキュメント更新
EOF
)" \
  --reviewer "$レビュアー"
```

## 完了

PRのURLを表示し、次のステップを案内:
- CI/CDの状態確認
- レビュアーへの通知
- マージ待ち
```

**特徴**:
- 対話型（AskUserQuestion）
- 動的コンテキスト挿入（感嘆符+バッククォート構文）
- 複雑なコマンド実行

## 例4: データベースマイグレーション

```yaml
---
name: db-migrate
description: データベースマイグレーションを作成・実行。マイグレーション、スキーマ変更、データベース更新を行う際に使用。
disable-model-invocation: true
allowed-tools:
  - Bash
  - Write
  - AskUserQuestion
context: fork
agent: general-purpose
---

# データベースマイグレーション

## マイグレーション種類

$ARGUMENTS[0]:
- "create": 新しいマイグレーションファイルを作成
- "up": マイグレーションを適用
- "down": マイグレーションを取り消し
- "status": マイグレーション状態を確認

## 新規マイグレーション作成

マイグレーション名を質問:
例: "add_posts_table", "add_user_email_index"

タイムスタンプ付きファイル作成:

```bash
TIMESTAMP=$(date +%Y%m%d%H%M%S)
FILENAME="migrations/${TIMESTAMP}_${名前}.sql"
```

テンプレート:

```sql
-- UP
-- ここに変更を記述

-- DOWN
-- ここにロールバックを記述
```

## マイグレーション適用

```bash
npm run migrate:up
```

適用前に確認:
- 現在のマイグレーション状態
- 適用されるマイグレーション一覧

## マイグレーション取り消し

```bash
npm run migrate:down
```

警告を表示し、確認を求める。

## 状態確認

```bash
npm run migrate:status
```

適用済み・未適用のマイグレーション一覧を表示。
```

**特徴**:
- 複数のサブコマンド
- サブエージェントで実行（安全性）
- 確認プロセス含む

## 使用方法

これらの例を参考に、自分のプロジェクトに合わせたタスク実行型skillを作成できます。

**ポイント**:
1. 明確なステップバイステップの指示
2. エラーハンドリングを含める
3. 必要に応じて対話型に
4. 危険な操作は `context: fork` で保護
5. `disable-model-invocation: true` で手動実行を推奨
