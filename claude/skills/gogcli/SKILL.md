---
name: gogcli
description: Google Suite CLI reference - use when user mentions Google services (Gmail, Calendar, Tasks, etc.) or asks about accessing Google Workspace from command line
user-invocable: true
---

# gogcli - Google Suite CLI Reference

高速でスクリプト向けのGoogle Suiteコマンドラインツール。Gmail、Calendar、Drive、Contacts、Tasks、Sheets、Docs、Slides、Chat、Classroomなどを操作可能。

## クイックスタート

### インストール
```bash
brew install steipete/tap/gogcli
```

### 初期設定
1. Google Cloud Consoleで OAuth2認証情報を作成
2. 認証情報を保存: `gog auth credentials <file>`
3. アカウント認可: `gog auth add you@gmail.com`
4. 動作確認: `gog gmail labels list`

### マルチアカウント
```bash
# アカウントエイリアス設定
gog auth alias set work work@company.com
gog auth alias set personal me@gmail.com

# エイリアス使用
gog --account work calendar events --today
```

## 重要: JSON出力を使う

**スクリプトや自動化では必ず `--json` オプションを付けてください。**

```bash
# ✅ 推奨: JSON形式で出力
gog gmail search 'is:unread' --json
gog calendar events --today --json
gog drive search "keyword" --json
gog tasks lists --json

# jqと組み合わせて加工
gog gmail search 'is:unread' --json | jq '.threads[] | .subject'
gog calendar events --today --json | jq '.events[] | .summary'
```

JSON出力により、安定したパース、エラーハンドリング、スクリプトの信頼性が向上します。

## よく使うコマンド早見表

### Gmail
```bash
gog gmail search 'from:boss@company.com is:unread' --json
gog gmail send --to user@example.com --subject "Subject" --body "Message"
```

### Calendar
```bash
gog calendar events --today --json
gog calendar create <calendarId> --summary "Meeting" --from "2026-01-30T14:00:00+09:00" --to "2026-01-30T15:00:00+09:00"
```

### Drive
```bash
# 簡易検索（ファイル名・フォルダ名から検索）
gog drive search "keyword" --json

# 詳細検索
gog drive search "name contains 'report' and mimeType = 'application/pdf'" --json
gog drive download <fileId>
```

### Sheets
```bash
gog sheets get <spreadsheetId> <range> --json
gog sheets update <spreadsheetId> <range> [<values> ...]
gog sheets export <spreadsheetId> --format xlsx
```

### Tasks
```bash
gog tasks lists --json
gog tasks create <tasklistId> --title "Task title"
```

## 詳細ドキュメント

各サービスの詳細は以下のファイルを参照：

- **Gmail**: `gmail.md` - メール検索、送信、フィルター管理
- **Calendar**: `calendar.md` - イベント管理、カレンダー操作
- **Drive**: `drive.md` - ファイル操作、検索、ファイル形式の理解
- **Sheets**: `sheets.md` - スプレッドシート操作、Excel変換
- **Docs/Slides**: `docs-slides.md` - ドキュメント・プレゼンテーション操作
- **Tasks**: `tasks.md` - タスク管理
- **Contacts**: `contacts.md` - 連絡先管理
- **その他のサービス**: `other-services.md` - Chat, Classroom, Keep
- **高度な機能**: `advanced-features.md` - 認証、JSON出力、サービスアカウント
- **実践例**: `workflows.md` - 実用的なスクリプト例

詳細なDrive検索クエリは `drive-query-guide.md` を参照。

## トラブルシューティング

### 認証エラー
```bash
# 認証情報の再設定
gog auth remove you@gmail.com
gog auth add you@gmail.com
```

### アカウント切り替え
```bash
# デフォルトアカウント設定
gog auth alias set default work@company.com

# 一時的に別アカウント使用
gog --account personal@gmail.com gmail labels list
```

### デバッグモード
```bash
# 詳細なログ出力
gog --debug gmail search 'test'
```

## 参考リンク

- GitHub: https://github.com/steipete/gogcli
- Google Cloud Console: https://console.cloud.google.com/
- OAuth2設定ガイド: https://github.com/steipete/gogcli#setup
