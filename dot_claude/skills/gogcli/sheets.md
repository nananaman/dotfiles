# Google Sheets コマンド

## 基本操作

### 値の取得
```bash
# Google Sheetsの値を取得
gog sheets get <spreadsheetId> <range>
gog sheets get 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms Sheet1!A1:B10
```

### 値の更新
```bash
# Google Sheetsの値を更新
gog sheets update <spreadsheetId> <range> [<values> ...]

# 値の追記
gog sheets append <spreadsheetId> <range> [<values> ...]

# 値のクリア
gog sheets clear <spreadsheetId> <range>
```

### メタデータとエクスポート
```bash
# メタデータ取得
gog sheets metadata <spreadsheetId>

# エクスポート（Excel/PDF/CSV形式）
gog sheets export <spreadsheetId> --format xlsx
gog sheets export <spreadsheetId> --format pdf
gog sheets export <spreadsheetId> --format csv --out ./output.csv
```

### 新規作成とコピー
```bash
# 新規作成
gog sheets create <title>

# コピー
gog sheets copy <spreadsheetId> <title>
```

## ExcelファイルとGoogle Sheetsの違い

### 重要な違い
Google DriveにはExcelファイル(.xlsx)とGoogle Sheetsの2種類が存在し、アクセス方法が異なります：

**Google Sheets** (ネイティブGoogle形式):
- MIME Type: `application/vnd.google-apps.spreadsheet`
- DriveのfileIdがそのままspreadsheetIdとして使用可能
- `gog sheets` コマンドで直接操作
- `gog sheets export` でExcel/PDF/CSVにエクスポート可能

**Excelファイル** (アップロードされたファイル):
- MIME Type: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- DriveのfileIdはspreadsheetIdとして使用**不可**
- `gog drive download <fileId>` でダウンロードするのみ
- Sheets APIでは直接読めない

### 形式の確認方法
```bash
# ファイル情報を取得してMIME Typeを確認
gog drive search "name contains 'report'" --json | jq '.files[] | {name, mimeType, id}'
```

## 実践例

### Excelファイルのダウンロード
```bash
#!/bin/bash
# Excelファイルを検索してダウンロード

# 1. Excelファイルを検索
EXCEL_ID=$(gog drive search "name contains 'report' and mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'" --json | \
  jq -r '.files[0].id')

# 2. ファイルをダウンロード
gog drive download "${EXCEL_ID}" --out ./report.xlsx
```

### Google Sheets ⇄ Excel 変換
```bash
#!/bin/bash
# Google Sheets → Excel
gog sheets export <spreadsheetId> --format xlsx --out ./output.xlsx

# Google Sheets → PDF
gog sheets export <spreadsheetId> --format pdf --out ./output.pdf

# Google Sheets → CSV
gog sheets export <spreadsheetId> --format csv --out ./output.csv
```

### Sheetsのデータ読み取り
```bash
#!/bin/bash
# Google Sheetsの内容をJSON形式で取得して加工

gog sheets get <spreadsheetId> "Sheet1!A1:Z100" --json | \
  jq '.values[] | @csv' > output.csv
```
