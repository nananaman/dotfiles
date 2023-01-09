# shell
set SHELL (which fish)

# cargo
set PATH $HOME/.cargo/bin $PATH

# go
set PATH /usr/local/go/bin $PATH
set PATH $HOME/go/bin $PATH

# fzf
if type -q fzf_configure_bindings
  fzf_configure_bindings --directory=\cf
end

# node
set PATH $HOME/.nodenv/bin $PATH
if type -q nodenv
  eval (nodenv init - | source)
end

# deno
set PATH $HOME/.deno/bin $PATH

# 1password
if type -q op
  op completion fish | source
end

# kubernetes
if count $HOME/.kube/*.yaml >/dev/null
  set -x KUBECONFIG (ls $HOME/.kube/*.yaml | tr '\n' ':'):(echo $KUBECONFIG)
end

# starship
if not type -q starship
  sh -c "(curl -fsSL https://starship.rs/install.sh)"
end

starship init fish | source
