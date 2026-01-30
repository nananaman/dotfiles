# Google Drive コマンド

## 基本操作

### ファイル一覧と操作
```bash
# ルートディレクトリのファイル一覧
gog drive ls

# 特定フォルダの内容を一覧表示
gog drive ls --parent <folderId>

# アップロード
gog drive upload /path/to/file

# ダウンロード
gog drive download <fileId>

# 共有ドライブ
gog drive ls --shared-drives

# 権限管理
gog drive permissions list <fileId>
```

## 検索クエリ（よく使うパターン）

### 簡易検索
```bash
# 簡易検索（ファイル名・フォルダ名から検索）
gog drive search "keyword"
```

### ファイル名で検索
```bash
# ファイル名で詳細検索
gog drive search "name contains 'report'"
gog drive search "name = 'exact-filename.pdf'"
```

### ファイル形式で検索
```bash
# ファイル形式で検索
gog drive search "mimeType = 'application/pdf'"
gog drive search "mimeType = 'application/vnd.google-apps.folder'"
gog drive search "mimeType contains 'image/'"
```

### 日時で検索
```bash
# 日時で検索
gog drive search "modifiedTime > '2026-01-01T00:00:00'"
gog drive search "createdTime > '2025-12-01' and createdTime < '2026-01-01'"
```

### フォルダ内の検索
```bash
# 特定フォルダ内のファイル
gog drive search "'<folderId>' in parents"
```

### 複数条件の組み合わせ
```bash
# 複数条件の組み合わせ
gog drive search "name contains 'report' and mimeType = 'application/pdf' and modifiedTime > '2026-01-01'"
gog drive search "(mimeType contains 'image/' or mimeType contains 'video/') and not trashed"
```

### その他の検索
```bash
# 全文検索
gog drive search "fullText contains 'keyword'"

# 共有ファイル・スター付き
gog drive search "sharedWithMe = true"
gog drive search "starred = true"

# ゴミ箱以外
gog drive search "trashed = false and name contains 'report'"
```

## ファイル形式の理解

Google Driveには異なるファイル形式があり、アクセス方法が異なります:

### Google Workspace形式（ネイティブGoogle形式）

**Google Sheets**:
- MIME Type: `application/vnd.google-apps.spreadsheet`
- `gog sheets` コマンドで直接操作
- `gog drive download --format xlsx` でExcel形式にエクスポート可能

**Google Docs**:
- MIME Type: `application/vnd.google-apps.document`
- `gog docs` コマンドまたは `gog drive download --format docx/pdf`

**Google Slides**:
- MIME Type: `application/vnd.google-apps.presentation`
- `gog slides` コマンドまたは `gog drive download --format pptx`

### Microsoft Office形式（アップロードされたファイル）

**Excel (.xlsx)**:
- MIME Type: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- `gog drive download <fileId>` でダウンロード
- Sheets APIでは直接読めない（Drive API経由のみ）

**Word (.docx)**:
- MIME Type: `application/vnd.openxmlformats-officedocument.wordprocessingml.document`

**PowerPoint (.pptx)**:
- MIME Type: `application/vnd.openxmlformats-officedocument.presentationml.presentation`

### 重要な注意点

**DriveのfileIdとSheetsのspreadsheetIdは異なります**:
- Google SheetsのfileIdは、spreadsheetIdとして使用可能
- ExcelファイルのfileIdは、spreadsheetIdとして使用不可（ダウンロードのみ）

## クエリ構文リファレンス

### 主要フィールド
- `name` - ファイル名（フォルダ名は含まない）
- `mimeType` - ファイル形式
- `fullText` - ファイル内容全体
- `modifiedTime` / `createdTime` - 更新/作成日時
- `parents` - 親フォルダ
- `trashed` - ゴミ箱状態
- `starred` - スター付き
- `sharedWithMe` - 共有ファイル

### 演算子
- `=` - 完全一致
- `!=` - 不一致
- `contains` - 部分一致
- `>` / `<` / `>=` / `<=` - 比較
- `in` - コレクション内
- `and` / `or` / `not` - 論理演算

### 注意点
- **フォルダ名で検索する場合は簡易検索を使用**（`name`はファイル名のみ）
- 文字列は必ずシングルクォートで囲む: `name = 'file.txt'`
- アポストロフィやバックスラッシュはエスケープ: `name = 'file\\'s name'`
- 日時はRFC3339形式: `'2026-01-30T12:00:00'`
- フレーズ検索はダブルクォート: `fullText contains '"hello world"'`

詳細な検索クエリは `drive-query-guide.md` を参照。
