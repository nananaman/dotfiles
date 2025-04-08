local autocmd = vim.api.nvim_create_autocmd

-- Timings
vim.opt.updatetime = 300

-- Indentation
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
-- ヤンクがクリップボードに入る
vim.opt.clipboard:append({ "unnamedplus" })
-- バッファが編集中でもその他のファイルを開けるように
vim.opt.hidden = true
vim.opt.termguicolors = true
-- 行番号を表示
vim.opt.number = true
-- 現在の行を強調表示
vim.opt.cursorline = true
-- ステータスラインを常に表示. Noice.nvim でコマンドラインは中央に表示している
vim.opt.laststatus = 2
-- signcolumn を常に表示
vim.o.signcolumn = "yes"
-- vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.virtualedit = "onemore"
vim.opt.showmatch = true
vim.opt.splitright = true

-- Backup
vim.opt.backup = false
vim.opt.undofile = false
vim.opt.swapfile = false

-- Wild
vim.opt.wildmode = "list:longest,full"
vim.opt.wildignorecase = true
vim.opt.wildignore = {
  -- Binary
  "*.aux",
  "*.out",
  "*.toc",
  "*.o",
  "*.obj",
  "*.dll",
  "*.jar",
  "*.pyc",
  "*.rbc",
  "*.class",
  "*.gif",
  "*.ico",
  "*.jpg",
  "*.jpeg",
  "*.png",
  "*.avi",
  "*.wav",
  -- Temp/System
  "*.*~",
  "*~ ",
  "*.swp",
  ".lock",
  ".DS_Store",
  "tags.lock",
}

-----------------------------------------------------------------------------//
-- Match and search
-----------------------------------------------------------------------------//
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.wrapscan = true
vim.opt.hlsearch = true

-- Remove whitespace on save
autocmd("BufWritePre", {
  pattern = "^(?!.*md$).+$",
  command = ":%s/\\s\\+$//e",
})
