# Gmail コマンド

## ラベル管理

```bash
# ラベル一覧
gog gmail labels list

# ラベル追加
gog gmail labels add <messageId> <labelName>

# ラベル削除
gog gmail labels remove <messageId> <labelName>
```

## スレッド操作

```bash
# スレッドのラベルを変更
gog gmail thread modify <threadId> --add <labelName>
gog gmail thread modify <threadId> --remove <labelName>

# スレッドの詳細を取得
gog gmail thread get <threadId> --json

# 未読メールを全て既読にする
gog gmail search 'is:unread' --json | jq -r '.threads[].id' | \
  while read thread_id; do
    gog gmail thread modify "$thread_id" --remove UNREAD
  done

# 特定の条件のメールにラベルを追加
gog gmail search 'from:notifications@service.com' --json | jq -r '.threads[].id' | \
  while read thread_id; do
    gog gmail thread modify "$thread_id" --add "Notifications"
  done
```

## メール検索

```bash
# 基本的な検索
gog gmail search 'newer_than:7d'
gog gmail search 'from:boss@company.com is:unread'

# JSON形式で出力
gog gmail search 'is:unread' --json
gog gmail search 'is:unread' --json | jq '.threads[] | .subject'
```

## メール送信

```bash
# 基本的な送信
gog gmail send --track
gog gmail send --to recipient@example.com --subject "Subject" --body "Message"

# 添付ファイル付き
gog gmail send \
  --to recipient@example.com \
  --subject "Subject" \
  --body "Message" \
  --attachment /path/to/file.pdf
```

## フィルター管理

```bash
# フィルター一覧
gog gmail filters list

# フィルター作成
gog gmail filters create
```

## 実践例

### 特定の送信者からの未読メールを自動処理
```bash
#!/bin/bash
gog gmail search 'from:notifications@service.com is:unread' --json | \
  jq -r '.threads[].id' | \
  xargs -I {} gog gmail labels add {} "auto-processed"
```

### レポートをメールで送信
```bash
#!/bin/bash
./generate-report.sh > report.txt
gog gmail send \
  --to team@company.com \
  --subject "Daily Report $(date +%Y-%m-%d)" \
  --body "$(cat report.txt)" \
  --attachment report.txt
```
