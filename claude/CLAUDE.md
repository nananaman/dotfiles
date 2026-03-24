## コーディング
- コメントは必要な箇所にのみ付け、自明なことは書かない

## テスト
- Arrage, Act, Assert のコメントを入れて読みやすくする
- 異常系のテストは正常系とは別の関数に分ける

## Worktree
- List worktrees: `git wt`
- Create/switch to worktree: `git wt <branch>` (creates if needed)
- Delete worktree: `git wt -d <branch>`
- Worktrees are created in `.wt/` directory
