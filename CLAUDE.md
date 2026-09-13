# Repository instructions

macOS arm64 と WSL x86_64 の dotfiles を mise で管理する repository。

## 設計

- ルート `mise.toml` に bootstrap の配置、OS packages、OS 設定と作業タスクを宣言する。
- グローバル CLI の一覧・pin は `home/.config/mise/config.toml` だけに置く。
- `home/` は HOME と同じ配置構造にし、設定は原則 symlink、機械依存値が必要なものだけ template にする。
- グローバル agent 指示は `home/.agents/AGENTS.md`、skill 依存は `home/.apm/apm.yml` を正本とする。
- 認証・セッション・取得済み skills などの状態を repository に取り込まない。
- 配置先の既存ファイルとディレクトリリンクを確認し、バックアップ方針を決めてから setup する。
- 配布する設定には literal な home directory を書かず、consumer の `~`、`$HOME`、mise template を使う。

## 検証と適用

```bash
mise run check
# nono profile の変更時
mise run check-sandbox
```

Neovim の Lua は stylua、shell は shfmt、TOML は taplo で整形する。
システムへの適用はユーザーが明示的に依頼した場合だけ実行する。

```bash
mise run preview
mise run setup
```

CLI の更新は `mise run update <tool>`、OS package の更新は `mise run update-packages`。
APM user-scope skills は `apm install -g` で展開する。
