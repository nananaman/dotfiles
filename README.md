# dotfiles

macOS arm64 / WSL x86_64 の環境を mise で管理する。
CLI のバージョンは `home/.config/mise/config.toml`、配置と OS パッケージはルートの `mise.toml` に宣言する。

## セットアップ

Nix に依存しない [mise](https://mise.jdx.dev/getting-started.html) 2026.9.5 以降が必要。
macOS は Homebrew と Xcode Command Line Tools、WSL は Ubuntu / Debian と sudo を用意する。
silicon とフォントは Linux でも mise の native brew backend で導入する。
AeroSpace と Orca の第三者 cask は mise 2026.9.5 の metadata DSL が対応していないため、`scripts/Brewfile` を Homebrew CLI で適用する。

```bash
mise trust
mise run preview
# パッケージ導入、dotfiles 配置、ログインシェル・OS 設定を適用
mise run setup
```

初回は `scripts/bootstrap.sh` が同じグローバル設定の正本を明示してツールを導入する。
Python による既存リンクの検査、OS パッケージ、CLI、dotfiles、補助処理の順に進む。
macOS の Touch ID 用 PAM、WSL の Windows フォントと Terminal 設定も setup の対象。
既存の PAM / Terminal 設定には `.pre-mise` バックアップを一度だけ作る。
`preview` は native bootstrap と CLI install の dry-run に、第三者 cask の予定一覧を加えたもの。PAM と login shell は native dry-run、スクリーンショット保存先は予定値を表示する。APM、npm ci、Windows 補助処理は実行しない。

## Nix 管理環境からの移行

ホストへの適用前に現在の Nix generation と元の checkout を保持する。Nix 自体のアンインストールはこの setup に含めない。
旧 Home Manager のリンクは元の checkout や Nix store を参照しているため、ファイル移動後もそのまま使えるとは限らない。

1. `mise run preview` で対象を確認する。
2. `python3 scripts/check-links.py` で旧ディレクトリリンクを列挙する。Python 3.11 以降が必要。
3. 列挙されたリンクと、配置先の既存ファイルを確認して、リンク自体を別名へ移す。リンク先の内容は削除しない。たとえば `mv ~/.config/nvim ~/.config/nvim.pre-mise`（同名バックアップがないことを先に確認）。通常ファイルも必要な差分を正本へ取り込んでからバックアップする。
4. `mise run setup` を実行し、新しいログインシェルで CLI とアプリを確認する。通常ファイルの競合は自動で上書きしない。
5. 旧 `~/.local/share/nono-agent-wrappers` や Nix の shell 初期化が PATH に残る場合は、その導入元を確認して外す。

復元時は mise が配置したリンクだけを取り除いて `.pre-mise` を元の名前へ戻す。必要に応じて旧 checkout と Nix generation を使って再適用する。PAM は管理者権限で復元し、Windows Terminal は Windows 側のバックアップを使う。OS パッケージや defaults はリンクの復元だけでは戻らないため、preview と元の設定を保存しておく。

## 日常の操作

```bash
# グローバルの Codex だけを更新し、pin を正本に記録
mise run update codex
# OS パッケージの更新は別操作
mise run update-packages
# 静的検査と隔離 HOME での配置・wrapper テスト
mise run check
# nono の filesystem / network / command 境界
mise run check-sandbox
# skill 依存の展開
apm install -g
```

CLI の更新は OS 設定の再適用を必要としない。Bun のバージョンを更新した場合は、実体パスを含む nono の pi profile を `mise bootstrap --only dotfiles` で再生成する。
`check` はツールを自動インストールしない。検証用 shellcheck、shfmt、taplo、Python もグローバル設定に含む。

## 構成

```text
mise.toml                  # setup 宣言と作業タスク
home/                      # HOME と同じ配置構造
  .config/mise/config.toml # グローバル CLI の pin
  .agents/AGENTS.md        # agent 指示の正本
  .apm/apm.yml             # skill 依存の正本
  .config/                # アプリ設定
  .local/bin/             # CLI wrapper
scripts/                   # bootstrap の補助処理
tests/                    # 配置と実行契約の検証
```

`.agents` / `.apm` は個別ファイルだけを配置し、取得済み skills、認証、キャッシュ、セッションを repository に取り込まない。
設定は原則 symlink、HOME や Bun の実体パスが必要な nono profile だけ template とする。

## Pre-push secretlint

`secretlint` と preset は lockfile 付きの独立した npm 環境へ導入する。
Git の `core.hooksPath` は `~/.config/git/hooks`。pre-push は push 対象の ref 差分を検査し、新規 branch で upstream がない場合は全 tracked files を検査する。
repository 内に `.secretlintrc*` があればそれを使い、なければ配布したグローバル設定を使う。
緊急時の bypass は `git push --no-verify`。

移行の対応表と検証範囲は [MIGRATION.md](MIGRATION.md) を参照。
