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
  let g:config_dir = expand('~/dotfiles/dein')
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
" let g:python3_host_prog = expand('/Users/j.watanabe/.pyenv/versions/3.6.5/bin/python')
let t_Co=256

""""""""""""""""""""
" setting
""""""""""""""""""""
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

" vim-airline設定
" タブを有効
let g:airline#extensions#tabline#enabled = 1
" タブに番号を振る
let g:airline#extensions#tabline#buffer_idx_mode = 1
" Tabを<C-o><C-p>で切り替え
nmap <C-o> <Plug>AirlineSelectPrevTab
nmap <C-p> <Plug>AirlineSelectNextTab
" テーマ
let g:airline_theme = 'gruvbox'
" PowerLineフォントを有効
let g:airline_powerline_fonts = 1

" coc.nvim設定
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
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Kでドキュメントを開く
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim', 'help'],  &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" カーソル下のカッコをハイライトする
autocmd CursorHold * silent call CocActionAsync('highlight')

" rn でリネーム
nmap <leader>rn <Plug>(coc-rename)

" <leader>fでフォーマット
xmap <leader>f <Plug>(coc-format-selected)
nmap <leader>f <Plug>(coc-format-selected)

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
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

" NERDTree設定
map <C-n> :NERDTreeToggle<CR>

" colorscheme設定
colorscheme gruvbox
set background=dark
let g:gruvbox_contrast_dark = 'hard'
let g:gruvbox_invert_indent_guides=1

" vimtex設定
let g:vimtex_compiler_latexmk = {
            \'background': 1,
            \'build_dir': '',
            \'continuous': 1,
            \'callback': 0,
            \'options': [
            \   '-pdfdvi',
            \   '-verbose',
            \   '-file-line-error',
            \   '-synctex=1',
            \   '-interaction=nonstopmode',
            \],
            \}

" instant_markdown設定
" markdownを自動で開かない
let g:instant_markdown_autostart = 0

" vim-indent-guides設定
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 2
let g:indent_guides_start_level = 2
let g:indent_guides_auto_colors = 1

" EasyMotion設定
" s{char}{char}{label}で移動 
nmap s <Plug>(easymotion-s2)

highlight Normal ctermbg=NONE guibg=NONE
highlight NonText ctermbg=NONE guibg=NONE
highlight LineNr ctermbg=NONE guibg=NONE

" vim-fugitive設定
nnoremap <leader>ga :Git add %:p<CR><CR>
nnoremap <leader>gc :Gcommit<CR><CR>
nnoremap <leader>gs :Gstatus<CR>
nnoremap <leader>gp :Gpush<CR>
nnoremap <leader>gd :Gdiff<CR>
nnoremap <leader>gl :Glog<CR>
nnoremap <leader>gb :Gblame<CR>
