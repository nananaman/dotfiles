# Repository instructions

macOS aarch64 環境の dotfiles を、Nix Flakes、nix-darwin、home-manager で管理する repository。

## 設計

- `flake.nix` を Nix 構成のエントリポイントとする。
- macOS のシステム設定は nix-darwin、ユーザー環境は home-manager で管理する。
- dotfile 本体は Nix で生成せず、この repository から out-of-store symlink する。
- package の導入と symlink の作成は Nix module で管理する。
- グローバル agent 指示は `agents/AGENTS.md` を source of truth とする。
- グローバル agent skill の依存一覧は `apm/apm.yml` を source of truth とする。

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
