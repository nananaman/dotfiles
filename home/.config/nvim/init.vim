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

nmap <silent> <C-o> :bprevious<CR>
nmap <silent> <C-p> :bnext<CR>

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

" fzf-preview.vim
set shell=/bin/bash
let $SHELL='/bin/bash'
let g:fzf_preview_command = 'bat --color=always --plain {-1}'
let g:fzf_preview_lines_command = 'bat --color=always --plain --number'
nnoremap <silent> ,f :<C-u>CocCommand fzf-preview.GitFiles<CR>
nnoremap <silent> ,b :<C-u>CocCommand fzf-preview.Buffers<CR>
nnoremap <silent> ,h :<C-u>CocCommand fzf-preview.ProjectMruFiles<CR>
nnoremap <silent> ,l :<C-u>CocCommand fzf-preview.Lines<CR>
nnoremap ,g :<C-u>CocCommand fzf-preview.ProjectGrep<Space>

" sonictemplate.vim
" <C-y><C-b>で後方補完
let g:sonictemplate_vim_template_dir = [ '~/.config/nvim/sonictemplate' ]

" Gina.vim設定
nnoremap <leader>gc :Gina commit<CR><CR>
nnoremap <leader>ga :<C-u>CocCommand fzf-preview.GitActions<CR>
nnoremap <leader>gs :<C-u>CocCommand fzf-preview.GitStatus<CR>

nnoremap <leader>gp :Gina push<CR>
nnoremap <leader>gd :Gina diff<CR>
nnoremap <leader>gl :Gina log<CR>
nnoremap <leader>gb :Gina blame<CR>

" vim-expand-region設定
map + <Plug>(expand_region_expand)
map - <Plug>(expand_region_shrink)

lua << EOF
-- Default options:
require('kanagawa').setup({
    undercurl = true,           -- enable undercurls
    commentStyle = "NONE",      -- 日本語を italic にすると崩れるので回避
    functionStyle = "NONE",
    keywordStyle = "italic",
    statementStyle = "bold",
    typeStyle = "NONE",
    variablebuiltinStyle = "italic",
    specialReturn = true,       -- special highlight for the return keyword
    specialException = true,    -- special highlight for exception handling keywords
    transparent = false,        -- do not set background color
    dimInactive = false,        -- dim inactive window `:h hl-NormalNC`
    globalStatus = false,       -- adjust window separators highlight for laststatus=3
    colors = {},
    overrides = {},
})

-- setup must be called before loading
vim.cmd("colorscheme kanagawa")

require("transparent").setup({
  enable = true, -- boolean: enable transparent
  extra_groups = { -- table/string: additional groups that should be clear
    -- In particular, when you set it to 'all', that means all avaliable groups

    -- example of akinsho/nvim-bufferline.lua
    "BufferLineTabClose",
    "BufferlineBufferSelected",
    "BufferLineFill",
    "BufferLineBackground",
    "BufferLineSeparator",
    "BufferLineIndicatorSelected",
  },
  exclude = {}, -- table: groups you don't want to clear
})

require('nvim-treesitter.configs').setup {
  highlight = {
    enable = true,
    disable = {}
  },
  ensure_installed = 'maintained'
}

require('lualine').setup {
  options = {theme = 'kanagawa'},
  sections = {
    lualine_c = {
      {
        'filename',
        file_status = true,   -- displays file status (readonly status, modified status)
        path = 1,             -- 0 = just filename, 1 = relative path, 2 = absolute path
        shorting_target = 40, -- Shortens path to leave 40 space in the window
                              -- for other components. Terrible name any suggestions?
        symbols = {
          modified = '[+]',      -- when the file was modified
          readonly = '[-]',      -- if the file is not modifiable or readonly
          unnamed = '[No Name]', -- default display name for unnamed buffers
        }
      }
    }
  }
}

require('indent_blankline').setup {
    show_current_context = true,
    show_current_context_start = true,
}

require('bufferline').setup {
  options = {
    show_buffer_close_icons = false,
    show_close_icon = false,
    diagnostics = 'coc',
    diagnostics_indicator = function(count, level, diagnostics_dict, context)
      local s = ' '
      for e, n in pairs(diagnostics_dict) do
        local sym = e == 'error' and ' '
          or (e == 'warning' and ' ' or '' )
        s = s .. sym .. n
      end
      return s
    end,
    separator_style = "slant",
  }
}

require('colorizer').setup {'css';'javascript';'html';'dart';'vue'}
require('hop').setup ()
EOF

" hop.nvim
nnoremap so :<C-u>HopChar1<CR>
nnoremap st :<C-u>HopChar2<CR>
nnoremap sl <Cmd>HopLine<CR>
nnoremap sw <Cmd>HopWord<CR>

" wilder.nvim
call wilder#setup({'modes': [':', '/', '?']})
call wilder#set_option('renderer', wilder#popupmenu_renderer(wilder#popupmenu_border_theme({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'highlights': {
      \   'border': 'Normal',
      \ },
      \ 'border': 'rounded',
      \ 'left': [
      \   ' ', wilder#popupmenu_devicons(),
      \ ],
      \ 'right': [
      \   ' ', wilder#popupmenu_scrollbar(),
      \ ],
      \ })))

" dex
command! -nargs=* -bang Dex silent only! | botright 12 split |
    \ execute 'terminal' (has('nvim') ? '' : '++curwin') 'dex'
    \   (<bang>0 ? '--clear ' : '') <q-args> ' ' expand('%:p') |
    \ stopinsert | execute 'normal! G' | set bufhidden=wipe |
    \ execute 'autocmd BufEnter <buffer> if winnr("$") == 1 | quit! | endif' |
    \ wincmd k
