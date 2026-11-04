#!/usr/bin/env python3
"""Summarize explicitly supplied macOS herdr-core sample reports offline."""

from datetime import datetime
import json
import os
import re
import stat
import sys


UNKNOWN = "unknown"
FIELDS = ("pid", "observed_at", "launched_at", "herdr_core_uuid", "main_thread_frames")
UUID = r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}"
FRAMES = {
    ("start", "dyld"),
    ("__private_getcwd", "libsystem_c.dylib"),
    ("__getcwd", "libsystem_c.dylib"),
    ("open$NOCANCEL", "libsystem_kernel.dylib"),
    ("__open_nocancel", "libsystem_kernel.dylib"),
}


def summarize(text):
    def single(pattern):
        matches = re.findall(pattern, text, re.MULTILINE)
        return matches[0] if len(matches) == 1 else UNKNOWN

    result = dict.fromkeys(FIELDS, UNKNOWN)
    if not (
        re.match(r"Analysis of sampling herdr-core \(pid [0-9]+\) every 1 millisecond\n", text)
        and single(r"^Platform: +(.+)$") == "macOS"
        and single(r"^Report Version: +(.+)$") == "7"
        and single(r"^Analysis Tool: +(.+)$") == "/usr/bin/sample"
    ):
        return result, ["unsupported_format"]

    pid = single(r"^Process: +herdr-core \[([1-9][0-9]*)\]$")
    if pid != UNKNOWN and text.startswith(f"Analysis of sampling herdr-core (pid {pid}) "):
        result["pid"] = int(pid)
    for key, label in (("observed_at", "Date/Time"), ("launched_at", "Launch Time")):
        value = single(rf"^{label}: +([0-9]{{4}}-[0-9]{{2}}-[0-9]{{2}} [0-9]{{2}}:[0-9]{{2}}:[0-9]{{2}}\.[0-9]{{3}} [+-][0-9]{{4}})$")
        try:
            datetime.strptime(value, "%Y-%m-%d %H:%M:%S.%f %z")
            result[key] = value
        except ValueError:
            pass
    images = text.split("\nBinary Images:\n")
    if len(images) == 2:
        matches = re.findall(
            rf"^ +0x[0-9a-f]+ - +0x[0-9a-f]+ \+herdr-core \(0\) <({UUID})> .+$",
            images[1], re.MULTILINE,
        )
        if len(matches) == 1:
            result["herdr_core_uuid"] = matches[0].upper()

    graph = text.split("\nCall graph:\n")
    if len(graph) == 2:
        main = re.findall(
            r"^    [0-9]+ Thread_[0-9]+   DispatchQueue_[0-9]+: com\.apple\.main-thread  \(serial\)\n"
            r"([\s\S]*?)(?=^    [0-9]+ Thread_|\nTotal number in stack|\nBinary Images:|\Z)",
            graph[1], re.MULTILINE,
        )
        if len(main) == 1:
            frames = []
            for line in main[0].splitlines():
                frame = re.fullmatch(
                    r"    \+ +[0-9]+ (.+?)  \(in ([^)]+)\) +(?:load address 0x[0-9a-f]+ )?"
                    r"\+ (?:0x[0-9a-f]+|[0-9]+)  \[0x[0-9a-f]+\]", line,
                )
                name, image = frame.groups() if frame else (UNKNOWN, UNKNOWN)
                if (name, image) == ("???", "herdr-core"):
                    name = "herdr-core (unknown symbol)"
                elif (name, image) not in FRAMES:
                    name = UNKNOWN
                if frames and frames[-1]["frame"] == name:
                    frames[-1]["count"] += 1
                else:
                    frames.append({"frame": name, "count": 1})
            if frames:
                result["main_thread_frames"] = frames

    issues = [key for key, value in result.items() if value == UNKNOWN]
    if isinstance(result["main_thread_frames"], list) and any(
        frame["frame"] == UNKNOWN for frame in result["main_thread_frames"]
    ):
        issues.append("unrecognized_main_thread_frame")
    return result, issues


def main(paths):
    if not paths:
        print("usage: inspect-sample.py SAMPLE_FILE [SAMPLE_FILE ...]", file=sys.stderr)
        return 2
    failed = False
    for index, path in enumerate(paths, 1):
        result = dict.fromkeys(FIELDS, UNKNOWN)
        try:
            with os.fdopen(os.open(path, os.O_RDONLY | os.O_NONBLOCK), encoding="utf-8") as source:
                if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                    issues = ["not_regular_file"]
                else:
                    result, issues = summarize(source.read())
        except OSError as error:
            issues = [f"read_error:{type(error).__name__}:errno={error.errno}"]
        except UnicodeError:
            issues = ["invalid_utf8"]
        print(json.dumps({"sample": index, **result, "issues": issues}, separators=(",", ":")))
        if issues:
            failed = True
            print(f"sample[{index}]: " + ", ".join(issues), file=sys.stderr)
    return int(failed)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
