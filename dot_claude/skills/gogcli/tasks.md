# Tasks コマンド

## タスクリスト管理

```bash
# タスクリスト一覧
gog tasks lists

# JSON形式で取得
gog tasks lists --json
```

## タスク管理

```bash
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

## 実践例

### 期限切れタスクの検出
```bash
#!/bin/bash
# 期限切れタスクを検出してSlackに通知
OVERDUE=$(gog tasks list <tasklistId> --json | \
  jq -r '[.tasks[] | select(.due < now)] | length')
if [ "$OVERDUE" -gt 0 ]; then
  echo "$OVERDUE overdue tasks found"
fi
```
