# 実践的なユースケース

## Driveファイルの検索と読み取り

### フォルダを探して中のファイルを読む
```bash
#!/bin/bash
# ワークフロー: フォルダを探して → 中のファイルを探して → 内容を読む

# 1. フォルダを検索（簡易検索でフォルダ名から検索）
FOLDER_ID=$(gog drive search "project-docs" --json | \
  jq -r '.files[] | select(.mimeType == "application/vnd.google-apps.folder") | .id' | head -1)

# 2. フォルダ内のGoogle Sheetsを検索
SHEET_ID=$(gog drive search "'${FOLDER_ID}' in parents and mimeType = 'application/vnd.google-apps.spreadsheet'" --json | \
  jq -r '.files[0].id')

# 3. Sheetsの内容を読み取り
gog sheets get "${SHEET_ID}" "Sheet1!A1:Z100" --json
```

### Excelファイルの読み取り
```bash
#!/bin/bash
# Excelファイルを検索してダウンロード

# 1. Excelファイルを検索
EXCEL_ID=$(gog drive search "name contains 'report' and mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'" --json | \
  jq -r '.files[0].id')

# 2. ファイルをダウンロード
gog drive download "${EXCEL_ID}" --out ./report.xlsx
```

### Google SheetsとExcelの相互変換
```bash
#!/bin/bash
# Google Sheets → Excel
gog sheets export <spreadsheetId> --format xlsx --out ./output.xlsx

# Google Sheets → PDF
gog sheets export <spreadsheetId> --format pdf --out ./output.pdf

# Google Sheets → CSV
gog sheets export <spreadsheetId> --format csv --out ./output.csv
```

### Drive内のファイル一括ダウンロード
```bash
#!/bin/bash
# 特定フォルダのファイルを全てダウンロード
gog drive search "parents in '<folderId>'" --json | \
  jq -r '.files[] | .id' | \
  xargs -I {} gog drive download {}
```

## Gmail自動処理

### 未読メールの自動処理
```bash
#!/bin/bash
# 特定の送信者からの未読メールをラベル付け
gog gmail search 'from:notifications@service.com is:unread' --json | \
  jq -r '.threads[].id' | \
  xargs -I {} gog gmail labels add {} "auto-processed"
```

### メール送信の自動化
```bash
#!/bin/bash
# レポートを生成してメールで送信
./generate-report.sh > report.txt
gog gmail send \
  --to team@company.com \
  --subject "Daily Report $(date +%Y-%m-%d)" \
  --body "$(cat report.txt)" \
  --attachment report.txt
```

## Calendar空き時間確認

### カレンダーの空き時間確認スクリプト
```bash
#!/bin/bash
# 今日の予定を確認して空いている時間を出力
gog calendar events --today --json | \
  jq '.events[] | "\(.start.dateTime) - \(.end.dateTime): \(.summary)"'
```

## Tasks自動化

### タスク管理の自動化
```bash
#!/bin/bash
# 期限切れタスクを検出してSlackに通知
OVERDUE=$(gog tasks list <tasklistId> --json | \
  jq -r '[.tasks[] | select(.due < now)] | length')
if [ "$OVERDUE" -gt 0 ]; then
  echo "$OVERDUE overdue tasks found"
fi
```
