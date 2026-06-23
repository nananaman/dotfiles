local function register_custom_parsers()
  require("nvim-treesitter.parsers").nu = {
    install_info = {
      url = "https://github.com/nushell/tree-sitter-nu",
      revision = "348b787d8b0409091d85fe9d4eb007fe9f3406bb",
      queries = "queries/nu",
    },
  }
end

local installing = {}

local function has_value(values, target)
  return vim.tbl_contains(values, target)
end

local function ensure_parser(treesitter, lang, bufnr)
  if has_value(treesitter.get_installed("parsers"), lang) then
    if bufnr then
      pcall(vim.treesitter.start, bufnr, lang)
    end
    return
  end

  if not has_value(treesitter.get_available(), lang) or installing[lang] then
    return
  end

  installing[lang] = true
  treesitter.install({ lang }):await(function()
    installing[lang] = nil
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.treesitter.start, bufnr, lang)
    end
  end)
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  config = function()
    register_custom_parsers()

    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("custom-treesitter-parsers", { clear = true }),
      pattern = "TSUpdate",
      callback = register_custom_parsers,
    })

    local treesitter = require("nvim-treesitter")

    treesitter.setup()
    ensure_parser(treesitter, "nu")

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter-highlight", { clear = true }),
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match) or args.match

        ensure_parser(treesitter, lang, args.buf)
      end,
    })
  end,
}
