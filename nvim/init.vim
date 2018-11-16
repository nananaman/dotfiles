"dein Scripts-----------------------------
if &compatible
  set nocompatible               " Be iMproved
endif

let s:dein_path = expand('~/.vim/dein')
let s:dein_repo_path = s:dein_path . 'repos/github.com/Shougo/dein.vim'

" dein.vimがなければgithubからclone
if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_path)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_path
  endif
  execute 'set runtimepath^=' . fnamemodify(s:dein_repo_path, ':p')
endif

" Required:
if dein#load_state(s:dein_path)
  call dein#begin(s:dein_path)

  " let g:config_dir = expand('~/.vim/dein/userconfig')
  let g:config_dir = expand('~/dotfiles/nvim/dein')
  let s:toml = g:config_dir . '/plugins.toml'
  let s:lazy_toml = g:config_dir . '/plugins_lazy.toml'

  " TOML 読み込み
  call dein#load_toml(s:toml, {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})

  " Required:
  call dein#end()
  call dein#save_state()
endif

" Required:
filetype plugin indent on
syntax enable

" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

"End dein Scripts-------------------------
"
""""""""""""""""""""
" setting
""""""""""""""""""""
" 文字コードをUTF-8に
set fenc=utf-8
" バックアップをとらない
set nobackup
" スワップファイルを作らない
set noswapfile
" 編集中のファイルが変更されたら自動で読み直す
set autoread
" バッファが編集中でもその他のファイルを開けるように
set hidden
" 入力中のコマンドをステータスに表示
set showcmd
" ヤンクがクリップボードに入る
set clipboard=unnamedplus

" 見た目系
" 行番号表示
set number
" 現在の行を強調表示
set cursorline
" 現在の行を強調表示(縦)
"set cursorcolumn
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

" Tab系
" Tabが意味するスペース数
set tabstop=4
" 自動インデントで入るスペース数
set shiftwidth=4
" Tabで入力されるスペース数
set softtabstop=4
" Tabでスペースが入力される
set expandtab
" 自動インデント
set autoindent
" {があると自動でインデント
set smartindent

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

" vim-airline設定
" タブを有効
let g:airline#extensions#tabline#enabled = 1
" タブに番号を振る
let g:airline#extensions#tabline#buffer_idx_mode = 1
" Tabを<C-o><C-p>で切り替え
nmap <C-o> <Plug>AirlineSelectPrevTab
nmap <C-p> <Plug>AirlineSelectNextTab
" ALEを表示
let g:airline#extensions#ale#enabled = 1

" テーマ
let g:airline_theme = 'gruvbox'
" PowerLineフォントを有効
let g:airline_powerline_fonts = 1

" NERDTree設定
map <C-n> :NERDTreeToggle<CR>

" colorscheme設定
colorscheme gruvbox
set background=dark
let g:gruvbox_contrast_dark = 'hard'
let g:gruvbox_invert_indent_guides=1

" deoplete設定
let g:deoplete#enable_at_startup = 1
let g:deoplete_camel_case = 1

" タブキーで補完候補選択
inoremap <expr><TAB> pumvisible() ? "<C-n>" : "\<TAB>"

" deoplete-jedi設定
let g:deoplete#sources#jedi#statement_length = 50

" vim-indent-guides設定
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
let g:indent_guides_auto_colors = 1

" autopep8設定
function! Preserve(command)
    " Save the last search.
    let search = @/
    " Save the current cursor position.
    let cursor_position = getpos('.')
    " Save the current window position.
    normal! H
    let window_position = getpos('.')
    call setpos('.', cursor_position)
    " Execute the command.
    execute a:command
    " Restore the last search.
    let @/ = search
    " Restore the previous window position.
    call setpos('.', window_position)
    normal! zt
    " Restore the previous cursor position.
    call setpos('.', cursor_position)
endfunction
    
function! Autopep8()
    call Preserve(':silent %!autopep8 -')
endfunction

autocmd FileType python nnoremap <S-f> :call Autopep8()<CR>

" ALE設定
let g:ale_sign_column_always = 1
let g:ale_virtualtext_cursor = 1
" <C-k>で前の、<C-j>で次のエラーにジャンプ
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" EasyMotion設定
" s{char}{char}{label}で移動 
nmap s <Plug>(easymotion-s2)
