# 基本テンプレート

シンプルなskill向けの基本テンプレートです。

## 構造

```yaml
---
name: skill-name
description: このskillが何をするか。どんなときに使うかを明記。
# オプションのフィールド:
# disable-model-invocation: true  # 手動実行のみ
# user-invocable: false           # バックグラウンド知識
# allowed-tools:                  # 許可するツール
#   - Read
#   - Bash
---

# Skill名

Skillの簡単な説明。

## 主要機能

このskillが提供する機能:
- 機能1
- 機能2
- 機能3

## 使用方法

### 基本的な使い方

具体的な手順や例:

1. ステップ1
2. ステップ2
3. ステップ3

### 例

実際の使用例を示す:

\`\`\`
コード例またはコマンド例
\`\`\`

## ポイント

- 重要なポイント1
- 重要なポイント2
```

## 参照型の場合

規約やパターンを示すskillの場合:

```yaml
---
name: coding-conventions
description: プロジェクトのコーディング規約とパターン。コードを書く際に参照。
user-invocable: false
---

# コーディング規約

## 命名規則

- 変数: camelCase
- 定数: UPPER_SNAKE_CASE
- 関数: camelCase
- クラス: PascalCase

## パターン

### パターン1

具体的な例:

\`\`\`typescript
// 良い例
export const handleUserLogin = async (credentials: Credentials) => {
  // ...
};

// 悪い例
export const login = (c) => {
  // ...
};
\`\`\`

### パターン2

別のパターン...
```

## タスク型の場合

具体的なアクションを実行するskillの場合:

```yaml
---
name: run-tests
description: プロジェクトのテストスイートを実行。テスト、ユニットテスト、統合テストを実行する際に使用。
allowed-tools:
  - Bash
  - Read
---

# テスト実行

## テストの種類

引数に応じて異なるテストを実行:

- 引数なし: すべてのテスト
- \`unit\`: ユニットテストのみ
- \`integration\`: 統合テストのみ

## 実行

### すべてのテスト

\`\`\`bash
npm run test
\`\`\`

### ユニットテスト

\`\`\`bash
npm run test:unit
\`\`\`

### 統合テスト

\`\`\`bash
npm run test:integration
\`\`\`

## 結果

テスト結果を表示し、失敗した場合は詳細を報告。
```

## カスタマイズのポイント

### 1. Description

**必ず含める**:
- 何をするか（機能）
- いつ使うか（トリガーワード）

**例**:
```yaml
description: APIエンドポイントを作成するためのガイド。新しいエンドポイント、REST API、GraphQL APIを作成する際に使用。
```

### 2. Allowed Tools

必要最小限のツールのみ指定:

```yaml
allowed-tools:
  - Read        # ファイル読み込み
  - Bash        # コマンド実行
  - Write       # ファイル作成
  - Edit        # ファイル編集
  - Grep        # コード検索
  - AskUserQuestion  # 対話
```

### 3. 本文の構成

**簡潔に**:
- SKILL.mdは500行未満
- 詳細は別ファイルに分離

**具体的に**:
- 抽象的な説明より具体例
- 実際のコードやコマンド

**明確に**:
- 曖昧な表現を避ける
- ステップバイステップ

## 検証

作成後、以下を確認:

- [ ] YAMLフロントマターが正しい
- [ ] descriptionに「何を」「いつ」が含まれる
- [ ] allowed-toolsが必要最小限
- [ ] 本文が簡潔で明確
- [ ] 具体例が含まれる
- [ ] 500行未満

## テスト

```bash
# chezmoiで適用
chezmoi apply

# 手動実行テスト
/skill-name

# 自動呼び出しテスト
# （descriptionに含まれるワードを使って質問）
```

## 次のステップ

1. 実際に使用してフィードバックを得る
2. 必要に応じて調整
3. サポートファイルの追加（オプション）
4. より高度な機能が必要な場合は `advanced-template.md` を参照
