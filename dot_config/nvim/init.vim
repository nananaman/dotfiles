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

  call dein#load_toml(s:toml, {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 0})

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
autocmd TermOpen * startinsert
" :T で下側にwindow作ってtermに入る
command! -nargs=* T split | wincmd j | resize 20 | terminal fish
" Escでinsertを抜ける
:tnoremap <Esc> <C-\><C-n>

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

" coc.nvim設定
" 起動時に必ず入れる拡張機能
let g:coc_global_extensions = [
  \'coc-fzf-preview',
  \'coc-spell-checker',
\]
" タブキーで補完候補選択
inoremap <silent><expr><TAB> pumvisible() ? "<C-n>" : <SID>check_back_space() ? "\<TAB>" : coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1] =~# '\s'
endfunction

" <c-space>で補完
inoremap <silent><expr> <c-space> coc#refresh()

" Use `[g` and `]g` to navigate diagnostics
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" 定義ジャンプ
nmap <silent> ge :<C-u>CocCommand fzf-preview.CocDiagnostics<CR>
nmap <silent> gce :<C-u>CocCommand fzf-preview.CocCurrentDiagnostics<CR>
" nmap <silent> gd :<C-u>CocCommand fzf-preview.CocDefinition<CR>
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy :<C-u>CocCommand fzf-preview.CocTypeDefinition<CR>
nmap <silent> gi :<C-u>CocCommand fzf-preview.CocImplementations<CR>
nmap <silent> gr :<C-u>CocCommand fzf-preview.CocReferences<CR>

" Kでドキュメントを開く
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim', 'help'],  &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

nnoremap <nowait><expr> <C-j> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-j>"
nnoremap <nowait><expr> <C-k> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-k>"
inoremap <nowait><expr> <C-j> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<CR>" : "\<Right>"
inoremap <nowait><expr> <C-k> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<CR>" : "\<Left>"

" カーソル下のカッコをハイライトする
autocmd CursorHold * silent call CocActionAsync('highlight')

" rn でリネーム
nmap <leader>rn <Plug>(coc-rename)

" <leader>fでフォーマット
xmap <leader>f <Plug>(coc-format)
nmap <leader>f <Plug>(coc-format)

augroup mygroup
  autocmd!
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Remap for do codeAction of selected region, ex: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap for do codeAction of current line
nmap <leader>ac  <Plug>(coc-codeaction)
" Fix autofix problem of current line
nmap <leader>qf  <Plug>(coc-fix-current)

" Create mappings for function text object, requires document symbols feature of languageserver.
xmap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap if <Plug>(coc-funcobj-i)
omap af <Plug>(coc-funcobj-a)

" Use <C-d> for select selections ranges, needs server support, like: coc-tsserver, coc-python
nmap <silent> <C-d> <Plug>(coc-range-select)
xmap <silent> <C-d> <Plug>(coc-range-select)

" Use `:Format` to format current buffer
command! -nargs=0 Format :call CocAction('format')

" Use `:Fold` to fold current buffer
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" use `:OR` for organize import of current buffer
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Using CocList
" Show all diagnostics
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<CR>
" Manage extensions
nnoremap <silent> <space>e  :<C-u>CocList extensions<CR>
" Show commands
nnoremap <silent> <space>c  :<C-u>CocList commands<CR>
" Find symbol of current document
nnoremap <silent> <space>o  :<C-u>CocList outline<CR>
" Search workspace symbols
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<CR>
" Do default action for next item.
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

lua << EOF
require('config')
EOF
