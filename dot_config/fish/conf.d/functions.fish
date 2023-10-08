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

function fgcd
  set -l repo ( ghq list | fzf +m --reverse )
  if string length -q -- $repo
    ghq get $repo
    and cd (ghq root)/$repo
  end
end

# 自分のリポジトリを検索してghq get
function fgget
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
function github-copilot_helper
    set -l TMPFILE (mktemp)
    trap 'rm -f $TMPFILE' EXIT
    if github-copilot-cli $argv[1] "$argv[2..]" --shellout $TMPFILE
        if [ -e "$TMPFILE" ]
            set -l FIXED_CMD (cat $TMPFILE)
            eval "$FIXED_CMD"
        else
            echo "Apologies! Extracting command failed"
        end
    else
        return 1
    end
end
alias ??='github-copilot_helper what-the-shell'
alias git?='github-copilot_helper git-assist'
alias gh?='github-copilot_helper gh-assist'
