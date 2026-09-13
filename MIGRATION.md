# Nix から mise への移行

状態: macOS の CLI・dotfiles・ユーザー設定を適用済み。Touch ID/PAM の設定と login shell の切り替えも確認済み。WSL 実機検証は未実施。
移行元: commit `867031a`、macOS arm64 / WSL x86_64。

## 管理の境界

CLI の更新が環境全体の build / switch を必要としない構成へ移した。

| 対象 | 正本・担当 |
| --- | --- |
| グローバル CLI のバージョン | `home/.config/mise/config.toml` |
| OS パッケージ、配置、OS defaults | ルート `mise.toml` の bootstrap 宣言 |
| dotfile 本体 | HOME と同じ構造の `home/` |
| Touch ID と WSL の Windows 連携 | `scripts/` |
| 認証、キャッシュ、セッション、取得済み skills | ホスト上の状態領域 |

mise の symlink / template 機能で配置する。独自のリンク管理実装は持たず、`check-links.py` は旧ディレクトリリンクを検出して停止するだけにした。
`.agents` / `.apm` 全体はリンクせず、指示と依存一覧の個別ファイルだけを配置する。

## パッケージの対応

| 旧導入対象 | 移行先 |
| --- | --- |
| sheldon、atuin、fzf、ripgrep、fd、lsd、bat、gh、ghq、lazygit | mise tools |
| Bun、Go、Deno、Neovim、tree-sitter、delta、Starship、rtk、gcloud | mise tools |
| Codex、nono、APM、hunk | mise registry の release 配布 |
| agent-browser、sandbox-runtime | mise npm backend |
| OMP | mise npm backend、明示解決した Bun で JavaScript entry point を実行 |
| Claude、pi（旧環境では本体を別途導入） | mise で本体も明示導入 |
| secretlint と preset | `package-lock.json` を使う独立した npm 環境 |
| Git、git-lfs、zsh | macOS は brew、WSL は apt |
| silicon、HackGen Nerd Font | bootstrap brew / brew-cask |
| azure-cli、colima、container、Docker 関連、qemu | macOS の bootstrap brew |
| 1password-cli、Ghostty | macOS の bootstrap brew-cask |
| AeroSpace、Orca | `scripts/Brewfile` を Homebrew CLI で適用（native DSL 非対応） |
| mise 自体 | Nix 外で導入。2026.9.5 以降が必要 |
| nixfmt | Nix 宣言の撤去に伴い常用対象から除外 |

既存のグローバル mise で管理していた Node、Python、uv、Java、Flutter、npm、pnpm、MySQL も一覧に保持した。
CLI はバージョンを明示し、`mise run update <tool>` で更新する。OS パッケージの再現性は配布元に従う。
APM の Python 依存は upstream の配布に委ね、旧 derivation の依存一覧を独立した CLI として重複導入しない。

## 設定と追加処理の対応

| 旧ソース・処理 | 新しい配置・処理 |
| --- | --- |
| `zsh/zshrc`、`zsh/functions`、`zsh/sheldon` | `home/.zshrc`、`home/.config/zsh/functions`、`home/.config/sheldon` |
| アプリ別のトップレベル設定 | `home/.config/` 配下 |
| Git / Starship / hunk の Nix module | 通常の config ファイルへ展開 |
| `agents/AGENTS.md`、`apm/` | `home/.agents/AGENTS.md`、`home/.apm/` |
| agent ごとの共通指示 | Claude、pi、Codex の入口から同じ正本へ symlink |
| `pi/agent/` | `home/.pi/agent/`。既存の未配置 extension は有効化しない |
| nono の HOME / Bun 置換 | mise template。Bun 更新後は dotfiles を再生成 |
| agent wrapper | `home/.local/bin/`。グローバル mise の raw executable を明示解決 |
| Dock / Finder / keyboard / screenshot type | mise bootstrap macOS defaults |
| screenshot location | `scripts/macos.sh` で HOME を解決 |
| sudo Touch ID + reattach | pam-reattach と `scripts/macos.toml` の sudo_local 宣言 |
| login shell | `scripts/macos.toml` / `scripts/linux.toml` の bootstrap user |
| Windows フォントと Terminal 設定 | `scripts/wsl.sh` と `scripts/windows.ps1` |
| secretlint / stylua の共有設定 | `home/.config` を正本にし、repo 側の設定も symlink |
| buildx の symlink | Apple Silicon Homebrew の配置先へリンク |
| host-artifact の未登録サービス・補助コマンド | 残骸と専用テストを撤去。サービスを起動しない |
| Nix flake / modules / lock / build・switch | 宣言を撤去。Nix 自体のアンインストールは行わない |

wrapper は引数、終了コード、呼び出し元ディレクトリを保持し、同名の自分自身への再帰を拒否する。
子コマンド向け PATH はプロジェクトの選択を保持する。mise activation 後も `~/.local/bin` を優先する。
共通 sandbox の既存許可は維持し、ghq 外の checkout でも配置元 `.zshrc` を読めるよう、同ファイルだけに読み取り許可を追加した。Linux では agent-browser が導入する `~/.agent-browser/browsers` も read-only にした。

## 検証と未確認の範囲

- mise 2026.9.5 を一時領域へ導入し、隔離 HOME で symlink / template 配置、再実行、既存ファイル競合、空白を含むパスを検証。
- macOS arm64 で Codex、nono、APM、hunk、Node、Bun、pi、OMP、agent-browser、sandbox-runtime と検査ツールを実際に導入。
- Codex / hunk / pi / OMP / agent-browser の起動と、別ディレクトリでの secretlint / preset 解決を検証。
- Codex の配布物に code-mode-host があることを確認。code mode の対話実行と Chromium の起動は未検証。
- CLI 一覧の macOS arm64 / Linux x64 向け backend 解決を検査。lock 非対応 backend があるため、全ツールの両 OS インストール成功を意味しない。
- 静的検査と配置・wrapper の自動テストは `mise run check`、nono の権限境界は `mise run check-sandbox` で検査する。
- 個別の `upgrade --bump` が symlink を保持し、正本の pin を更新することを隔離設定で検証。
- macOS で95ファイルの配置、CLI 6種と Neovim の起動、shell の Node/npm/uvx 選択、secretlint、nono の設定読み取りを確認。defaults は適用済み。2026-09-13 に Touch ID/PAM の設定と login shell `/opt/homebrew/bin/zsh` への切り替えを確認。
- WSL と Windows PowerShell での実行は未検証。
- 実ホストの旧設定は `~/.local/state/dotfiles/migration-20260912-105909` に保存。Nix 本体と旧 generation は保持している。

bootstrap は Python、旧リンク検査、OS packages、CLI、dotfiles、補助処理の順に実行する。初回でも template が必要とする実体パスをツール導入後に解決する。
移行時のバックアップと復元は [README.md](README.md) を参照。元の checkout と Nix generation を保持したうえで、ホストへの適用を別工程として行う。
