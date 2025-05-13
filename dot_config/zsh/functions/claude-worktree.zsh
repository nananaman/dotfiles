#!/bin/zsh

function claude-worktree() {
  # 引数が指定されているか確認
  if [ $# -lt 1 ]; then
    echo "使用法: claude-worktree <ブランチ名>"
    return 1
  fi

  local branch_name="$1"
  local claude_base_dir="$HOME/claude"
  
  # プロジェクトのルートディレクトリを見つける
  local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "エラー: Gitリポジトリではありません"
    return 1
  fi
  
  # プロジェクト名を取得 (ディレクトリ名を使用)
  local project_name=$(basename "$git_root")
  
  # 作成するディレクトリのパス
  local worktree_dir="$claude_base_dir/${project_name}-${branch_name}"
  
  # ~/claudeディレクトリが存在するか確認し、なければ作成
  if [ ! -d "$claude_base_dir" ]; then
    mkdir -p "$claude_base_dir"
  fi
  
  # 既にブランチが存在するか確認
  if git show-ref --verify --quiet refs/heads/"$branch_name"; then
    echo "ブランチ '$branch_name' は既に存在しています"
  else
    # ブランチを作成
    echo "ブランチ '$branch_name' を作成します"
    git branch "$branch_name"
  fi
  
  # worktreeが既に存在するか確認
  if [ -d "$worktree_dir" ]; then
    echo "エラー: $worktree_dir は既に存在します"
    return 1
  fi
  
  # git worktreeを作成
  echo "worktreeを作成: $worktree_dir"
  git worktree add "$worktree_dir" "$branch_name"
  
  if [ $? -eq 0 ]; then
    echo "成功: ${project_name}-${branch_name} worktreeを作成しました"
    echo "パス: $worktree_dir"
    
    # 作成したディレクトリに移動するかどうか尋ねる
    echo -n "作成したworktreeディレクトリに移動しますか？ [Y/n] "
    read answer
    
    if [[ "$answer" =~ ^[Yy]$ ]] || [[ -z "$answer" ]]; then
      cd "$worktree_dir"
    fi
  else
    echo "エラー: worktreeの作成に失敗しました"
    return 1
  fi
}