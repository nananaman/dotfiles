git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
yes | ~/.fzf/install

echo '[ -f ~/.fzf.bash ] && source ~/.fzf.bash' >> ~/.bashrc

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install --locked bat
cargo install lsd
