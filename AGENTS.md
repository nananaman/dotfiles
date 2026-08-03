# Repository instructions

macOS（aarch64-darwin）と WSL（x86_64-linux）の dotfiles を、Nix Flakes、nix-darwin、home-manager で管理する repository。

## 設計

- `flake.nix` を Nix 構成のエントリポイントとする。
- macOS のシステム設定は nix-darwin、macOS と WSL のユーザー環境は home-manager で管理する。
- dotfile 本体は Nix で生成せず、この repository から out-of-store symlink する。
- package の導入と symlink の作成は Nix module で管理する。
- グローバル agent 指示は `agents/AGENTS.md` を source of truth とする。
- グローバル agent skill の依存一覧は `apm/apm.yml` を source of truth とする。
- Flake から新規ファイルを参照するときは、Git の追跡対象と確認できるまで build 検証へ進まない（理由: Git source の Flake は未追跡ファイルを入力に含めない）。
- activation や手動配置から `home.file` へ管理を移すときは、既存 target を確認し、`force`、backup、または削除の方針を決めてから switch する（理由: build 成功後の activation で clobber が発覚するため）。
- 配布する dotfile には literal な home directory を書かず、consumer が対応する `~`、`$HOME`、または Home Manager の値を使う（理由: username と配置場所への不要な依存を防ぐため）。

## 検証と適用

Nix の変更後は、対象ファイルを `nixfmt` で整形し、次を実行する。

```bash
nix run .#build
```

Neovim の Lua ファイルは `stylua` で整形する。

システムへの適用は、ユーザーが明示的に依頼した場合にのみ実行する。

```bash
nix run .#switch
```

その他の操作:

```bash
# flake.lock を更新
nix run .#update

# APM user-scope skills を展開
apm install -g
```
