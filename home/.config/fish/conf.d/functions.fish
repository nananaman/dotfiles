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
    and exec fish
  end
  cd -
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
