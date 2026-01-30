# 高度な機能

## JSON出力（スクリプト向け）

```bash
# JSON形式で出力
gog gmail search 'is:unread' --json | jq '.threads[] | .subject'

# プレーンテキスト（TSV）
gog calendar events --today --plain
```

## 認証管理

### 読み取り専用モード
```bash
# 読み取り専用で認証（安全）
gog auth add --readonly you@gmail.com

# Drive特定スコープ
gog auth add --drive-scope you@gmail.com
```

### 認証エラーの解決
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

## サービスアカウント（Workspace）

```bash
# ドメイン全体委任でサービスアカウント使用
gog --service-account sa@project.iam.gserviceaccount.com
```

## コマンド許可リスト（サンドボックス環境）

```bash
# 特定コマンドのみ許可
gog --enable-commands "gmail:search,calendar:events"
```

## デバッグモード

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
