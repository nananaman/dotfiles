# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Overview

macOS (aarch64-darwin) dotfiles managed by Nix Flakes + nix-darwin + home-manager.

## Commands

```bash
# ドライビルド
nix run .#build

# ビルド＆適用（sudo必要）
nix run .#switch

# flake.lock 更新
nix run .#update
```

## Operational Guidelines

- 変更は最小限・局所的に行い、無関係なファイルを編集しない。
- `nix run .#build` は必要に応じて検証に使う。
- `nix run .#switch` は実環境へ適用し sudo が必要なため、明示的に依頼された場合のみ実行する。
- `nix run .#update` や `flake.lock` の更新は、依存更新が目的のタスクでのみ行う。
- 秘密情報、トークン、認証情報、個人用の private path を追加しない。

## Architecture

**flake.nix** がエントリポイント。`darwinConfigurations` で nix-darwin + home-manager を組み合わせている。

### Nix モジュール構成

- `nix/modules/darwin/system.nix` — macOS システム設定（Dock, Finder, キーボード）、Homebrew casks
- `nix/modules/home/` — home-manager モジュール群
  - `packages.nix` — CLI ツール一覧（zsh, fzf, ripgrep, neovim 等）
  - `dotfiles.nix` — `home.activation` でシンボリックリンクを作成（nvim, zsh, ghostty 等をこのリポジトリから直接リンク）
  - `programs/` — home-manager の `programs.*` を使うアプリ設定（git, starship, claude-code, codex）
- `nix/modules/lib/helpers/` — activation 用のユーティリティ関数
- `nix/overlays/` — カスタムパッケージオーバーレイ（現在は空）

### dotfiles の管理方式

設定ファイルは Nix で生成するのではなく、このリポジトリに直接置いて `dotfiles.nix` の `link_force` でシンボリックリンクしている。Nix が管理するのはパッケージインストールとリンク作成のみ。

### Agent-specific configuration

- `AGENTS.md` はこのリポジトリで作業する coding agent 向けの共通指示。
- `CLAUDE.md` は Claude Code 互換のため `AGENTS.md` への symlink。
- `claude/` は `~/.claude/` にリンクされる Claude Code のグローバル設定管理元。project-local な `.claude/` ではない。
- `codex/instructions.md` は Codex CLI 向けのグローバル指示。

### Nix フォーマット

Nix ファイルは `nixfmt` (RFC style) でフォーマットする。

### Lua フォーマット

`stylua.toml` でフォーマット設定済み。Neovim の Lua ファイルは `stylua` を使う。
