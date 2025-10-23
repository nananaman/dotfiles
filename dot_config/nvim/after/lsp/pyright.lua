---@type vim.lsp.Config
return {
  root_markers = { "uv.lock", ".git" }, -- pyproject.toml を指定すると uv workspace の場合に各 workspace ごとにサーバーが起動してしまう
  settings = {
    python = {
      pythonPath = "./.venv/bin/python",
    },
  },
}
