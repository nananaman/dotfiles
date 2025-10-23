---@type vim.lsp.Config
return {
  cmd = { "sourcekit-lsp" },
  filetypes = { "swift", "c", "cpp", "objective-c", "objective-cpp" },
  root_dir = lspconfig.util.root_pattern(
    "buildServer.json",
    "*.xcodeproj",
    "*.xcworkspace",
    ".git",
    "compile_commands.json",
    "Package.swift"
  ),
}
