# Calendar コマンド

## カレンダー管理

```bash
# カレンダー一覧
gog calendar calendars

# カレンダーIDをJSON形式で取得
gog calendar calendars --json
```

## イベント管理

```bash
# 今日の予定（デフォルトカレンダー）
gog calendar events --today

# 特定カレンダーの予定
gog calendar events <calendarId> --today

# プレーンテキスト（TSV）形式
gog calendar events --today --plain

# JSON形式
gog calendar events --today --json
```

## イベント作成

```bash
# イベント作成（書き込み権限が必要）
gog calendar create <calendarId> \
  --summary "Meeting" \
  --from "2026-01-30T14:00:00+09:00" \
  --to "2026-01-30T15:00:00+09:00"
```

## 実践例

### 空き時間確認スクリプト
```bash
#!/bin/bash
# 今日の予定を確認して空いている時間を出力
gog calendar events --today --json | \
  jq '.events[] | "\(.start.dateTime) - \(.end.dateTime): \(.summary)"'
```
