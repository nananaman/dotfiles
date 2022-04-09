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
  set -l tgt ( chezmoi managed | fzf +m --reverse )
  if string length -q -- $tgt
    chezmoi edit ~/$tgt --apply
    and exec fish
  end
end
