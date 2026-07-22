# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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

# APM user-scope agent skills を展開
apm install -g
```

## Architecture

**flake.nix** がエントリポイント。`darwinConfigurations` で nix-darwin + home-manager を組み合わせている。

### Nix モジュール構成

- `nix/modules/darwin/system.nix` — macOS システム設定（Dock, Finder, キーボード）、Homebrew casks
- `nix/modules/home/` — home-manager モジュール群
  - `packages.nix` — CLI ツール一覧（zsh, fzf, ripgrep, neovim, apm-cli 等）
  - `dotfiles.nix` — `home.activation` でシンボリックリンクを作成（nvim, zsh, ghostty 等をこのリポジトリから直接リンク）
  - `programs/` — home-manager の `programs.*` を使うアプリ設定（git, starship, Codex, codex）
- `nix/modules/lib/helpers/` — activation 用のユーティリティ関数
- `nix/overlays/` — カスタムパッケージオーバーレイ（現在は空）

### dotfiles の管理方式

設定ファイルは Nix で生成するのではなく、このリポジトリに直接置いて `dotfiles.nix` の `link_force` でシンボリックリンクしている。Nix が管理するのはパッケージインストールとリンク作成のみ。

### Nix / Home Manager の変更規則

- Flake から新規ファイルを参照するときは、Git の追跡対象と確認できるまで build 検証へ進まない（理由: Git source の Flake は未追跡ファイルを入力に含めない）。
- activation や手動配置から `home.file` へ管理を移すときは、既存 target を確認し、`force`、backup、または削除の方針を決めてから switch する（理由: build 成功後の activation で clobber が発覚するため）。
- 配布する dotfile には literal な home directory を書かず、consumer が対応する `~`、`$HOME`、または Home Manager の値を使う（理由: username と配置場所への不要な依存を防ぐため）。

### Global Agent Instructions

グローバル agent 指示は `agents/AGENTS.md` を唯一の source of truth として管理する。home-manager が同じファイルを `~/.claude/CLAUDE.md`, `~/.config/codex/instructions.md`, `~/.pi/agent/AGENTS.md` にリンクする。

### Agent Skills

グローバル agent skills のインストール一覧は `apm/apm.yml` で管理する。自作汎用 skill 本体は `nananaman/skills` を source-of-truth にし、dotfiles 側から full SHA で pin して参照する。`dotfiles.nix` が `apm/` を `~/.apm` にリンクし、`apm install -g` が `target: claude,agent-skills` に従って `~/.claude/skills` と `~/.agents/skills` に展開する。`apm.lock.yaml` と `apm_modules/` は `apm/.gitignore` で除外するため、外部 dependency は full SHA で pin する。

### Nix フォーマット

Nix ファイルは `nixfmt` (RFC style) でフォーマットする。

### Lua フォーマット

`stylua.toml` でフォーマット設定済み。Neovim の Lua ファイルは `stylua` を使う。
