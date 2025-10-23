return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  opts = {
    format_on_save = {
      -- These options will be passed to conform.format()
      timeout_ms = 500,
      lsp_format = "fallback",
    },
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "isort", "ruff_format" },
      sql = { "sql_formatter" },
      go = { "golines", "gofmt" },
      toml = { "taplo" },
      -- You can customize some of the format options for the filetype (:help conform.format)
      -- rust = { "rustfmt", lsp_format = "fallback" },
      -- Conform will run the first available formatter
      -- javascript = { "prettierd", "prettier", stop_after_first = true },
    },
    formatters = {
      sql_formatter = {
        args = { "--config", vim.fn.getenv("HOME") .. "/.config/sql-formatter/config.json" },
      },
      golines = {
        args = { "-max-len", "120" },
      },
    },
  },
}
