# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

### Nix フォーマット

Nix ファイルは `nixfmt` (RFC style) でフォーマットする。

### Lua フォーマット

`stylua.toml` でフォーマット設定済み。Neovim の Lua ファイルは `stylua` を使う。
