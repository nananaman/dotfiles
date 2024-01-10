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

function fgcd
  set -l repo ( ghq list | fzf +m --reverse )
  if string length -q -- $repo
    ghq get $repo
    and cd (ghq root)/$repo
  end
end

# 自分のリポジトリを検索してghq get
function fghq
  # gh cli の存在確認
  if not type gh > /dev/null
    echo "gh cli is not installed"
    # gh cli のインストール
    # OS別にインストールコマンドを変える
    if type brew > /dev/null
      brew install gh
    else if type apt > /dev/null
      sudo apt install gh
    else
      echo "gh cli install failed"
      return 1
    end
  end

  # gh cli の認証確認
  if not gh auth status > /dev/null
    echo "gh cli is not authenticated"
    gh auth login
  end

  # リポジトリの検索
  set -l sshUrl ( gh repo list --source --json sshUrl --jq '.[].sshUrl' | fzf +m --reverse )
  if string length -q -- $sshUrl
    set -l repo ( echo $sshUrl | sed 's#git@github\.com:#github\.com/#' | sed 's#\.git$##' )
    ghq get $sshUrl
    and cd (ghq root)/$repo
  end
end

set -U fish_features qmark-noglob
