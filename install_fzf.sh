git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
yes | ~/.fzf/install

echo '[ -f ~/.fzf.bash ] && source ~/.fzf.bash' >> ~/.bashrc
