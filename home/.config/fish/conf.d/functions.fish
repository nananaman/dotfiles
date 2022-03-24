set fish_greeting

function playjs
  # 開発用設定の整っているディレクトリへ移動
  # cd ~/ghq/github.com/kawarimidoll/deno-dev-template/

  # JSファイル名
  set -l filename "playground.js"

  # ファイル作成
  and echo 'console.log("Playground start");' > "$filename"

  # 作ったファイルを開き、:Dexコマンドで自動実行をスタート
  # 最初に入力されている内容を消去し、インサートモードに遷移
  and nvim "$filename" \
    -c 'Dex' \
    -c 'delete _' \
    -c 'startinsert' \
    -c 'nnoremap :q <cmd>qa!<CR>'

  # 終了後、入力内容をコピー（pbcopyはmacOS用）
  # cat "$filename" | pbcopy

  # 終了後、ファイルを削除
  and rm -f "$filename"
end

function fbr
  set -l branch ( git branch -vv | fzf +m --reverse  )
  and git checkout ( echo $branch | awk '{print $1}' | sed 's/.* //'  )
end

function fbrm
  set -l branches ( git branch --all | grep -v HEAD  )
  and set -l branch ( string collect $branches | fzf -d (math 2 + (count $branches)) +m --reverse  )
  and git checkout ( echo $branch | sed 's/.* //' | sed 's#remotes/[^/]*/##'  )
end

function fvd
  cd ~/dotfiles
  set -l tgt ( find . -type f -not -path '*/\.git/*' | fzf +m --reverse )
  if string length -q -- $tgt
    vim $tgt
    and make deploy
    and cd -
    and exec fish
  else
    cd -
  end
end

function ghq-migrater-check -d 'call ghq-migrator'
  bash ~/dotfiles/scripts/ghq-migrator.bash (pwd)
end

function ghq-migrater-migrate -d 'call ghq-migrator and run'
  GHQ_MIGRATOR_ACTUALLY_RUN=1 bash ~/dotfiles/scripts/ghq-migrator.bash (pwd)
end

function f -d 'ghqで管理してるプロジェクトをfzfで検索してsessionで開く'
  set -l project ( ghq list | fzf +m --reverse --prompt='Project > ' )
  if not string length -q $project
    return
  end

  set -l dir ( ghq root )/$project
  if string length -q $TMUX
    set repo ( basename $project )
    set session ( string replace . - $repo )
    set current_session ( tmux list-sessions | grep attached | cut -d: -f1 )

    if string match -r '^[0-9]+$' $current_session
      tmux rename-session $session
      cd $dir
    else
      tmux list-sessions | cut -d: -f1 | grep -e "^$session\$" > /dev/null
      if test $status -ne 0
        tmux new-session -d -c $dir -s $session
      end
      tmux switch-client -t $session
    end
  end
end
