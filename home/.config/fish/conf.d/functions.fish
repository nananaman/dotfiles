set fish_greeting

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

function tmuxpopup -d 'toggle tmux popup window'
  set width '80%'
  set height '80%'
  set session ( tmux display-message -p -F '#{session_name}' )
  if contains 'popup' $session
    tmux detach-client
  else
    tmux popup -d '#{pane_current_path}' -xC -yC -w$width -h$height -E "tmux attach -t popup || tmux new -s popup"
  end
end

function inittmux -d 'シェル起動時に呼んでtmuxに入ってなければ入る'
  if not string length -q $TMUX
    set -l sessions ( tmux list-sessions )
    if string length -q "$sesions"
      tmux new-session
      return
    end

    set -l create_new_session "Create New Session"
    set -l sessions $sessions "$create_new_session"
    set -l session_id ( string join \n $sessions | fzf +m --reverse | cut -d: -f1 )
    if test "$session_id" = "$create_new_session"
      tmux new-session
    else if string length -q "$session_id"
      tmux attach-session -t $session_id
    end
  end
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
    echo $session

    if string match -r '^[0-9]+$' $current_session
      cd $dir
      tmux rename-session $session
    else
      tmux list-sessions | cut -d: -f1 | grep -e "^$session\$" > /dev/null
      if test $status -ne 0
        tmux new-session -d -c $dir -s $session
      end
      tmux switch-client -t $session
    end
  else
    cd $dir
  end
end

if status --is-login
  inittmux
end
