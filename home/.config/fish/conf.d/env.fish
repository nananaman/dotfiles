# shell
set SHELL /usr/local/bin/fish

# path
set PATH $HOME/.cargo/bin /usr/local/go/bin $PATH

# fzf
fzf_configure_bindings --directory=\cf

# starship
if not type -q starship
  sh -c "(curl -fsSL https://starship.rs/install.sh)"
end

starship init fish | source
