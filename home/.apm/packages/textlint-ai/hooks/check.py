"""Return textlint findings to Claude Code and Codex after Markdown edits."""

import json
from pathlib import Path
import subprocess
import sys


def edited_files(event):
    tool_input = event.get("tool_input", {})
    if event.get("tool_name") == "apply_patch":
        files = []
        for line in tool_input.get("command", "").splitlines():
            if line.startswith(("*** Add File: ", "*** Update File: ")):
                files.append(line.split(": ", 1)[1])
            elif line.startswith("*** Move to: ") and files:
                files[-1] = line.removeprefix("*** Move to: ")
        return files
    file_path = tool_input.get("file_path")
    return [file_path] if file_path else []


def main():
    event = json.load(sys.stdin)
    cwd = Path(event.get("cwd") or Path.cwd())
    files = list(dict.fromkeys(
        str(cwd / file) for file in edited_files(event)
        if Path(file).suffix.lower() == ".md"
    ))
    if not files:
        return 0
    try:
        result = subprocess.run(
            [str(Path.home() / ".local/bin/textlint-ai"), *files],
            capture_output=True, text=True,
        )
    except OSError as error:
        print(f"textlint-ai hook: {error}", file=sys.stderr)
        return 2
    if result.returncode:
        print(result.stdout + result.stderr, file=sys.stderr, end="")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
