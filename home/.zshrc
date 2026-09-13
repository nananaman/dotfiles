export EDITOR=nvim
export VISUAL=nvim

# Preserve independently installed user commands.
path=("$HOME/bin" "$HOME/go/bin" "$HOME/.ticloud/bin" $path "$HOME/.cargo/bin")

# Activate tools before initializing plugins that invoke them.
eval "$(mise activate zsh)"

eval "$(sheldon source)"
eval "$(starship init zsh)"

# load config files
ZSH_CONFIG_DIR="$HOME/.config/zsh"
if [ -d "$ZSH_CONFIG_DIR" ]; then
  for file in "$ZSH_CONFIG_DIR"/functions/*.zsh(N); do
    source "$file"
  done
fi

# alias
alias vi="nvim"
alias vim="nvim"

alias ls="lsd"
alias la="ls -a"
alias ll="ls -al"

alias cat="bat"

alias k="kubectl"
alias kc="kubectx"
alias kn="kubens"
alias cwt="claude-worktree"

# abbr
abbr import-aliases -S --quieter

# functions
zle -N ghq-project-widget
bindkey "^f" ghq-project-widget

# fzf history
function fzf-select-history() {
    BUFFER=$(history -n -r 1 | fzf --query "$LBUFFER" --reverse)
    CURSOR=$#BUFFER
    zle reset-prompt
}

zle -N fzf-select-history
bindkey "^r" fzf-select-history

bindkey "^[[F" end-of-line
bindkey "^[[H" beginning-of-line

# atuin
eval "$(atuin init zsh)"

# Keep wrappers ahead of runtime executables after mise activation.
path=("$HOME/.local/bin" $path)
