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

## 主要コマンド

### Gmail
```bash
# ラベル一覧
gog gmail labels list

# メール検索
gog gmail search 'newer_than:7d'
gog gmail search 'from:boss@company.com is:unread'

# メール送信
gog gmail send --track
gog gmail send --to recipient@example.com --subject "Subject" --body "Message"

# フィルター管理
gog gmail filters list
gog gmail filters create
```

### Calendar
```bash
# カレンダー一覧
gog calendar calendars

# 今日の予定（デフォルトカレンダー）
gog calendar events --today

# 特定カレンダーの予定
gog calendar events <calendarId> --today

# カレンダーIDをJSON形式で取得
gog calendar calendars --json

# イベント作成（書き込み権限が必要）
gog calendar create <calendarId> --summary "Meeting" --from "2026-01-30T14:00:00+09:00" --to "2026-01-30T15:00:00+09:00"
```

### Drive

#### 基本的なファイル操作
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

#### 検索クエリ（よく使うパターン）
```bash
# 簡易検索（ファイル名・フォルダ名から検索）
gog drive search "katohome"
gog drive search "report"

# ファイル名で詳細検索
gog drive search "name contains 'report'"
gog drive search "name = 'exact-filename.pdf'"

# ファイル形式で検索
gog drive search "mimeType = 'application/pdf'"
gog drive search "mimeType = 'application/vnd.google-apps.folder'"
gog drive search "mimeType contains 'image/'"

# 日時で検索
gog drive search "modifiedTime > '2026-01-01T00:00:00'"
gog drive search "createdTime > '2025-12-01' and createdTime < '2026-01-01'"

# 特定フォルダ内のファイル
gog drive search "'<folderId>' in parents"

# 複数条件の組み合わせ
gog drive search "name contains 'report' and mimeType = 'application/pdf' and modifiedTime > '2026-01-01'"
gog drive search "(mimeType contains 'image/' or mimeType contains 'video/') and not trashed"

# 全文検索
gog drive search "fullText contains 'keyword'"

# 共有ファイル・スター付き
gog drive search "sharedWithMe = true"
gog drive search "starred = true"

# ゴミ箱以外
gog drive search "trashed = false and name contains 'report'"
```

#### クエリ構文リファレンス

**主要フィールド**:
- `name` - ファイル名
- `mimeType` - ファイル形式
- `fullText` - ファイル内容全体
- `modifiedTime` / `createdTime` - 更新/作成日時
- `parents` - 親フォルダ
- `trashed` - ゴミ箱状態
- `starred` - スター付き
- `sharedWithMe` - 共有ファイル

**演算子**:
- `=` - 完全一致
- `!=` - 不一致
- `contains` - 部分一致
- `>` / `<` / `>=` / `<=` - 比較
- `in` - コレクション内
- `and` / `or` / `not` - 論理演算

**注意点**:
- 文字列は必ずシングルクォートで囲む: `name = 'file.txt'`
- アポストロフィやバックスラッシュはエスケープ: `name = 'file\\'s name'`
- 日時はRFC3339形式: `'2026-01-30T12:00:00'`
- フレーズ検索はダブルクォート: `fullText contains '"hello world"'`

詳細は `drive-query-guide.md` を参照。

### Tasks
```bash
# タスクリスト一覧
gog tasks lists

# タスク一覧
gog tasks list <tasklistId>

# タスク作成
gog tasks create <tasklistId> --title "Task title"

# タスク更新
gog tasks update <tasklistId> <taskId>

# タスク完了/未完了
gog tasks done <tasklistId> <taskId>
gog tasks undo <tasklistId> <taskId>

# タスク削除
gog tasks delete <tasklistId> <taskId>
```

### Contacts
```bash
# 連絡先検索
gog contacts search "name:John"

# 連絡先作成
gog contacts create

# 連絡先更新
gog contacts update <resourceName>
```

### Sheets
```bash
# スプレッドシート読み込み
gog sheets read <spreadsheetId> <range>

# スプレッドシート書き込み
gog sheets write <spreadsheetId> <range> <values>
```

### Docs/Slides
```bash
# PDF/DOCX/PPTXへのエクスポート
gog docs export <documentId> --format pdf
gog slides export <presentationId> --format pptx
```

### Chat (Workspace)
```bash
# スペースへメッセージ送信
gog chat message spaces/<spaceId>

# ダイレクトメッセージ
gog chat message dm/<userId>
```

### Classroom
```bash
# コース管理
gog classroom courses list

# 課題管理
gog classroom coursework list <courseId>
```

### Keep (Workspace only)
```bash
# ノート管理
gog keep notes list
gog keep notes create
```

## 高度な機能

### JSON出力（スクリプト向け）
```bash
# JSON形式で出力
gog gmail search 'is:unread' --json | jq '.messages[] | .subject'

# プレーンテキスト（TSV）
gog calendar events --today --plain
```

### 読み取り専用モード
```bash
# 読み取り専用で認証（安全）
gog auth add --readonly you@gmail.com

# Drive特定スコープ
gog auth add --drive-scope you@gmail.com
```

### サービスアカウント（Workspace）
```bash
# ドメイン全体委任でサービスアカウント使用
gog --service-account sa@project.iam.gserviceaccount.com
```

### コマンド許可リスト（サンドボックス環境）
```bash
# 特定コマンドのみ許可
gog --enable-commands "gmail:search,calendar:events"
```

## 実践的なユースケース

### 未読メールの自動処理
```bash
#!/bin/bash
# 特定の送信者からの未読メールをラベル付け
gog gmail search 'from:notifications@service.com is:unread' --json | \
  jq -r '.messages[].id' | \
  xargs -I {} gog gmail labels add {} "auto-processed"
```

### カレンダーの空き時間確認スクリプト
```bash
#!/bin/bash
# 今日の予定を確認して空いている時間を出力
gog calendar events --today --json | \
  jq '.items[] | "\(.start.dateTime) - \(.end.dateTime): \(.summary)"'
```

### Drive内のファイル一括ダウンロード
```bash
#!/bin/bash
# 特定フォルダのファイルを全てダウンロード
gog drive search "parents in '<folderId>'" --json | \
  jq -r '.files[] | .id' | \
  xargs -I {} gog drive download {}
```

### タスク管理の自動化
```bash
#!/bin/bash
# 期限切れタスクを検出してSlackに通知
OVERDUE=$(gog tasks list <tasklistId> --json | \
  jq -r '[.items[] | select(.due < now)] | length')
if [ "$OVERDUE" -gt 0 ]; then
  echo "$OVERDUE overdue tasks found"
fi
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

## ベストプラクティス

1. **エイリアス活用**: 複数アカウントはエイリアスで管理
2. **JSON出力**: スクリプトでは必ず `--json` を使う
3. **最小権限**: 読み取りのみの場合は `--readonly` で認証
4. **エラーハンドリング**: スクリプトでは終了コードをチェック
5. **レート制限**: Google API制限に注意し、適切な間隔を空ける

## 参考リンク

- GitHub: https://github.com/steipete/gogcli
- Google Cloud Console: https://console.cloud.google.com/
- OAuth2設定ガイド: https://github.com/steipete/gogcli#setup
