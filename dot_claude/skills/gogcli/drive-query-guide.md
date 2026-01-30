# Google Drive検索クエリ完全ガイド

このガイドは、Google Drive APIの検索クエリ構文を詳しく解説します。`gog drive search`コマンドで使用できる全てのクエリパターンをカバーします。

## 基本構文

```
gog drive search "<field> <operator> <value>"
```

- `<field>`: 検索対象のフィールド（name, mimeType等）
- `<operator>`: 比較演算子（=, contains, in等）
- `<value>`: 検索値（必ずシングルクォートで囲む）

## クエリフィールド一覧

### ファイル属性

| フィールド | 説明 | 例 |
|----------|------|-----|
| `name` | ファイル名 | `name = 'report.pdf'` |
| `fullText` | ファイル内容全体 | `fullText contains 'keyword'` |
| `mimeType` | MIMEタイプ | `mimeType = 'application/pdf'` |
| `modifiedTime` | 最終更新日時 | `modifiedTime > '2026-01-01T00:00:00'` |
| `createdTime` | 作成日時 | `createdTime < '2025-12-31T23:59:59'` |
| `viewedByMeTime` | 最終閲覧日時 | `viewedByMeTime > '2026-01-01'` |
| `trashed` | ゴミ箱状態 | `trashed = false` |
| `starred` | スター付き | `starred = true` |

### 共有・権限

| フィールド | 説明 | 例 |
|----------|------|-----|
| `sharedWithMe` | 共有ファイル | `sharedWithMe = true` |
| `owners` | 所有者 | `'user@example.com' in owners` |
| `writers` | 編集者 | `'user@example.com' in writers` |
| `readers` | 閲覧者 | `'user@example.com' in readers` |
| `sharingUser` | 共有したユーザー | `sharingUser = 'user@example.com'` |

### フォルダ・階層

| フィールド | 説明 | 例 |
|----------|------|-----|
| `parents` | 親フォルダ | `'folderId' in parents` |
| `'root' in parents` | ルート直下 | `'root' in parents` |

### プロパティ

| フィールド | 説明 | 例 |
|----------|------|-----|
| `properties` | カスタムプロパティ | `properties has { key='status' and value='draft' }` |
| `appProperties` | アプリプロパティ | `appProperties has { key='tag' and value='important' }` |

### ラベル（Workspace）

| フィールド | 説明 | 例 |
|----------|------|-----|
| `labels` | ラベル | `labels/department contains 'engineering'` |

## 演算子

### 比較演算子

| 演算子 | 説明 | 対応型 | 例 |
|--------|------|--------|-----|
| `=` | 完全一致 | すべて | `name = 'file.txt'` |
| `!=` | 不一致 | すべて | `mimeType != 'application/pdf'` |
| `<` | より小さい | 日時、数値 | `modifiedTime < '2026-01-01'` |
| `<=` | 以下 | 日時、数値 | `createdTime <= '2025-12-31'` |
| `>` | より大きい | 日時、数値 | `modifiedTime > '2026-01-01'` |
| `>=` | 以上 | 日時、数値 | `createdTime >= '2026-01-01'` |
| `contains` | 部分一致 | 文字列 | `name contains 'report'` |
| `in` | コレクション内 | リスト | `'user@example.com' in owners` |
| `has` | プロパティ保持 | オブジェクト | `properties has { key='status' }` |

### 論理演算子

| 演算子 | 説明 | 例 |
|--------|------|-----|
| `and` | 論理積 | `name contains 'report' and mimeType = 'application/pdf'` |
| `or` | 論理和 | `mimeType contains 'image/' or mimeType contains 'video/'` |
| `not` | 論理否定 | `not trashed` |

**優先順位**: `not` > `and` > `or`

**グループ化**: 括弧 `()` を使用
```bash
gog drive search "(mimeType contains 'image/' or mimeType contains 'video/') and not trashed"
```

## よく使うMIMEタイプ

### Google Workspace

```bash
# フォルダ
mimeType = 'application/vnd.google-apps.folder'

# Google Docs
mimeType = 'application/vnd.google-apps.document'

# Google Sheets
mimeType = 'application/vnd.google-apps.spreadsheet'

# Google Slides
mimeType = 'application/vnd.google-apps.presentation'

# Google Forms
mimeType = 'application/vnd.google-apps.form'
```

### 一般ファイル

```bash
# PDF
mimeType = 'application/pdf'

# Microsoft Word
mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'

# Microsoft Excel
mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

# Microsoft PowerPoint
mimeType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'

# 画像（全般）
mimeType contains 'image/'

# 動画（全般）
mimeType contains 'video/'

# テキストファイル
mimeType = 'text/plain'
```

## 日時フォーマット

### RFC3339形式（推奨）

```bash
# 完全形式
modifiedTime > '2026-01-30T12:00:00+09:00'

# UTC（タイムゾーン省略時はUTC）
modifiedTime > '2026-01-30T12:00:00'

# 日付のみ（00:00:00として扱われる）
modifiedTime > '2026-01-30'
```

### 相対日時

Google Drive APIは相対日時をサポートしていないため、スクリプトで計算:

```bash
#!/bin/bash
# 過去7日間
SINCE=$(date -u -v-7d +"%Y-%m-%dT%H:%M:%S")
gog drive search "modifiedTime > '${SINCE}'"

# 今月
MONTH_START=$(date -u +"%Y-%m-01T00:00:00")
gog drive search "modifiedTime > '${MONTH_START}'"
```

## エスケープルール

### アポストロフィ（シングルクォート）

```bash
# バックスラッシュでエスケープ
gog drive search "name = 'file\\'s name.txt'"
```

### バックスラッシュ

```bash
# バックスラッシュを2つ重ねる
gog drive search "name contains '\\\\server\\\\share'"
```

### ダブルクォート（フレーズ検索）

```bash
# fullTextでフレーズ検索する場合
gog drive search 'fullText contains "\"hello world\""'

# シェルのクォートに注意
gog drive search "fullText contains '\"hello world\"'"
```

## 実践例

### ファイル管理

```bash
# 今月作成されたPDFファイル
gog drive search "mimeType = 'application/pdf' and createdTime > '2026-01-01' and trashed = false"

# 1GB以上の大きなファイル（注: sizeはAPI v3で非推奨）
# 代わりにJSON出力でフィルタ
gog drive search "trashed = false" --json | jq '.files[] | select(.size > 1073741824)'

# 特定フォルダ内の画像ファイル
gog drive search "'<folderId>' in parents and mimeType contains 'image/'"

# ルート直下のフォルダのみ
gog drive search "'root' in parents and mimeType = 'application/vnd.google-apps.folder'"
```

### 共有ファイル管理

```bash
# 自分と共有されたPDFファイル
gog drive search "sharedWithMe = true and mimeType = 'application/pdf'"

# 特定ユーザーが所有するファイル
gog drive search "'user@example.com' in owners"

# 特定ユーザーから共有されたファイル
gog drive search "sharingUser = 'user@example.com' and sharedWithMe = true"

# 編集権限があるファイル
gog drive search "'me' in writers and not 'me' in owners"
```

### 期間指定検索

```bash
# 過去30日以内に更新されたファイル
gog drive search "modifiedTime > '2025-12-31T00:00:00' and trashed = false"

# 特定期間に作成されたファイル
gog drive search "createdTime > '2026-01-01' and createdTime < '2026-02-01'"

# 長期間更新されていないファイル（アーカイブ候補）
gog drive search "modifiedTime < '2024-01-01' and trashed = false"
```

### カスタムプロパティ

```bash
# プロパティが存在するファイル
gog drive search "properties has { key='status' }"

# プロパティの値が一致
gog drive search "properties has { key='status' and value='draft' }"

# 複数プロパティの組み合わせ
gog drive search "properties has { key='project' and value='alpha' } and properties has { key='status' and value='active' }"
```

### ゴミ箱管理

```bash
# ゴミ箱内のファイル
gog drive search "trashed = true"

# ゴミ箱に入れられた日時で絞り込み
gog drive search "trashed = true and trashedTime > '2026-01-01'"

# 完全に削除可能なファイル（30日以上前にゴミ箱へ）
gog drive search "trashed = true and trashedTime < '2025-12-31'"
```

## スクリプトでの活用

### 一括処理パターン

```bash
#!/bin/bash
# 検索結果を取得してIDを抽出
FILE_IDS=$(gog drive search "name contains 'backup' and modifiedTime < '2024-01-01'" --json | \
  jq -r '.files[].id')

# 各ファイルに対して処理
for id in $FILE_IDS; do
  echo "Processing: $id"
  gog drive download "$id"
done
```

### エラーハンドリング

```bash
#!/bin/bash
# 検索結果が空の場合の処理
RESULT=$(gog drive search "name = 'missing-file.txt'" --json)
if [ "$(echo "$RESULT" | jq '.files | length')" -eq 0 ]; then
  echo "ファイルが見つかりません"
  exit 1
fi
```

### ページネーション

```bash
#!/bin/bash
# 全結果を取得（デフォルトは100件まで）
# nextPageTokenを使って続きを取得
gog drive search "trashed = false" --json --page-size 1000
```

## 制限事項と注意点

### API制限

- **検索結果の上限**: デフォルト100件、最大1000件/リクエスト
- **クエリの長さ**: 最大4096文字
- **レート制限**: プロジェクトごとに毎秒のクエリ数制限あり

### 検索の制約

- **部分一致の方向**: `contains`は前方一致・中間一致のみ（後方一致は遅い）
- **大文字小文字**: 基本的に区別されない
- **ワイルドカード**: サポートなし（`*`や`?`は使えない）
- **正規表現**: サポートなし

### fullTextの注意点

- **インデックス化**: 最近作成/更新されたファイルはインデックス化に時間がかかる
- **対象ファイル**: テキストベースのファイルのみ（画像・動画は不可）
- **Google Workspace**: Docs/Sheets/Slidesの本文も検索可能
- **PDF**: テキスト抽出可能なPDFのみ検索対象

## トラブルシューティング

### 検索結果が不完全

```bash
# インデックス化待ちの可能性
# 少し時間を置いて再検索

# または明示的にファイルIDを指定
gog drive search "'<folderId>' in parents" --json
```

### クエリエラー

```bash
# エラー: Invalid Value
# → シングルクォートで囲んでいるか確認
gog drive search "name = file.txt"  # NG
gog drive search "name = 'file.txt'"  # OK

# エラー: Invalid Query
# → 演算子と型の組み合わせを確認
gog drive search "name > 'file.txt'"  # NG (nameは文字列、>は使えない)
gog drive search "name contains 'file'"  # OK
```

### パフォーマンス最適化

```bash
# 具体的な条件を先に指定
gog drive search "mimeType = 'application/pdf' and name contains 'report'"  # Good

# trashedのフィルタは必ず追加（デフォルトで含まれる）
gog drive search "trashed = false and name contains 'report'"

# 不要な全文検索は避ける（遅い）
gog drive search "fullText contains 'keyword'"  # 必要な場合のみ
```

## 参考リンク

- [Google Drive API - Search for files](https://developers.google.com/drive/api/guides/search-files)
- [Google Drive API - Search query terms](https://developers.google.com/drive/api/guides/ref-search-terms)
- [MIME types reference](https://developers.google.com/drive/api/guides/mime-types)
