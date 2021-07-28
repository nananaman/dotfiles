# shell
set SHELL /usr/local/bin/fish

# cargo
set PATH $HOME/.cargo/bin $PATH

# go
set PATH /usr/local/go/bin $PATH
set PATH $HOME/go/bin $PATH

# fzf
fzf_configure_bindings --directory=\cf

# ghq
fzf_configure_bindings --directory=\cf
bind \cb '__ghq_repository_search'

# starship
if not type -q starship
  sh -c "(curl -fsSL https://starship.rs/install.sh)"
end

starship init fish | source
