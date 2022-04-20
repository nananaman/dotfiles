" dein Scripts-----------------------------
if &compatible
  set nocompatible               " Be iMproved
endif

" Required:
set runtimepath+=~/.cache/dein/repos/github.com/Shougo/dein.vim

if dein#load_state('~/.cache/dein')
  " Required:
  call dein#begin('~/.cache/dein')

  " Let dein manage dein
  " Required:
  call dein#add('~/.cache/dein/repos/github.com/Shougo/dein.vim')

  " Load plugins
  let g:config_dir = expand('~/.config/nvim/dein')
  let s:toml = g:config_dir . '/plugins.toml'
  let s:lazy_toml = g:config_dir . '/plugins_lazy.toml'
  let s:cmp_toml = g:config_dir . '/nvim_lsp.toml'

  call dein#load_toml(s:toml, {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})
  call dein#load_toml(s:cmp_toml, {'lazy': 1})

  " Required:
  call dein#end()
  call dein#save_state()
endif

" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

" Required:
filetype plugin indent on
syntax enable

"End dein Scripts-------------------------

""""""""""""""""""""
" setting
""""""""""""""""""""
set modifiable
" 文字コードをUTF-8に
set fenc=utf-8
" バックアップをとらない
set nobackup
" スワップファイルを作らない
set noswapfile
" ファイルを上書きする前にバックアップを作ることを無効化
set nowritebackup
" 編集中のファイルが変更されたら自動で読み直す
set autoread
" バッファが編集中でもその他のファイルを開けるように
set hidden
" 入力中のコマンドをステータスに表示
set showcmd
" ヤンクがクリップボードに入る
set clipboard=unnamedplus
set clipboard+=unnamed
" 更新間隔
set updatetime=300

" 見た目系
set termguicolors
" 行番号表示
set number
" 現在の行を強調表示
set cursorline
" 行末の１文字先までカーソル移動可能
set virtualedit=onemore
" スマートインデント
set smartindent
" 括弧入力時、対応する括弧を表示
set showmatch
" ステータスラインを常に表示
set laststatus=2
" コマンドラインの補完
set wildmode=list:longest

" ins-completion-menu 関連のメッセージを表示しない
set shortmess+=c
set signcolumn=yes

" Tab系
" Tabが意味するスペース数
set tabstop=2
" 自動インデントで入るスペース数

set shiftwidth=2
" Tabで入力されるスペース数
set softtabstop=2
" Tabでスペースが入力される
set expandtab
" 自動インデント
" set autoindent
" {があると自動でインデント
" set smartindent


" 検索系
" 検索文字列が小文字の場合、大文字小文字を区別しない
set ignorecase
" 検索文字列に大文字が含まれている場合、それらを区別
set smartcase

" 検索文字列入力時に順次ヒット
set incsearch
" 検索時に最後まで行ったら最初に戻る
set wrapscan
" 検索語をハイライト表示
set hlsearch
" Esc連打でハイライト解除
nmap <Esc><Esc> :nohlsearch<CR><Esc>
" 保存時に行末のスペースoを削除
autocmd BufWritePre * :%s/\s\+$//ge

" 画面分割
nmap <silent> <C-w>\| :vsplit<CR>
nmap <silent> <C-w>- :split<CR>

" tablineを表示
set showtabline=2

" Bufferを<C-o><C-p>で切り替え
" nmap <silent> <C-o> :bprevious<CR>
" nmap <silent> <C-p> :bnext<CR>

" term周りの設定
" デフォルトでinsertモード
" autocmd TermOpen * startinsert
" :T で下側にwindow作ってtermに入る
" command! -nargs=* T split | wincmd j | resize 20 | terminal fish
" Escでinsertを抜ける
" :tnoremap <Esc> <C-\><C-n>

" Markdownのとき, 選択した文字列にpでリンクを追加する
let s:clipboard_register = has('linux') || has('unix') ? '+' : '*'
function! InsertMarkdownLink() abort
  " use register `9`
  let old = getreg('9')
  let link = trim(getreg(s:clipboard_register))
  if link !~# '^http.*'
    normal! gvp
    return
  endif

  " replace `[text](link)` to selected text
  normal! gv"9y
  let word = getreg(9)
  let newtext = printf('[%s](%s)', word, link)
  call setreg(9, newtext)
  normal! gv"9p

  " restore old data
  call setreg(9, old)
endfunction

augroup markdown-insert-link
  au!
  au FileType markdown vnoremap <buffer> <silent> p :<C-u>call InsertMarkdownLink()<CR>
augroup END


" ##############
" ## Plugins  ##
" ##############

" fern.vim設定
map <silent> <C-n> :Fern . -reveal=% -drawer -toggle<CR>
let g:fern#renderer = "nerdfont"
function! s:fern_settings() abort
  nmap <silent> <buffer> p     <Plug>(fern-action-preview:toggle)
  nmap <silent> <buffer> <C-p> <Plug>(fern-action-preview:auto:toggle)
  nmap <silent> <buffer> <C-d> <Plug>(fern-action-preview:scroll:down:half)
  nmap <silent> <buffer> <C-u> <Plug>(fern-action-preview:scroll:up:half)
endfunction

augroup fern-settings
  autocmd!
  autocmd FileType fern call s:fern_settings()
  autocmd FileType fern call glyph_palette#apply()
augroup END

lua << EOF
require('config')
EOF
