# install go
if [ "$(uname)" == 'Darwin' ]; then
  brew install go
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  apt-get install golang
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

# code2img
git clone https://github.com/skanehira/code2img
cd code2img && go install

# memo
go get github.com/mattn/memo

# twty
go get github.com/mattn/twty
