{ config, dotfilesDir, ... }:
let
  agentsFile = "${dotfilesDir}/agents/AGENTS.md";
in
{
  home.file = {
    ".agents/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink agentsFile;
    ".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink agentsFile;
    ".pi/agent/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink agentsFile;
  };

  xdg.configFile."codex/instructions.md".source = config.lib.file.mkOutOfStoreSymlink agentsFile;
}
