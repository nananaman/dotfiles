#!/usr/bin/env python3
"""Project an existing hc get JSON from stdin without connecting to anything."""

import json
import sys


FIELDS = ("address", "state", "status", "turn", "exit_code", "signal", "reason", "reported")


def compact(raw):
    def object_from_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    def invalid_constant(value):
        raise ValueError("nonfinite JSON number")

    try:
        data = json.loads(raw, object_pairs_hook=object_from_pairs, parse_constant=invalid_constant)
    except (ValueError, UnicodeError):
        raise ValueError("invalid JSON") from None
    if not isinstance(data, dict):
        raise ValueError("invalid terminal schema")
    if isinstance(data.get("error"), dict):
        return {"error": data["error"]}, False
    if any(key not in data for key in FIELDS):
        raise ValueError("missing terminal field")

    status = data["status"]
    valid_status = status is None or (
        isinstance(status, dict) and isinstance(status.get("state"), str)
        and all(isinstance(status[key], str) for key in ("app", "msg", "title") if key in status)
        and ("kind" not in status or status["kind"] is None or isinstance(status["kind"], str))
        and ("progress" not in status or status["progress"] is None or (
            type(status["progress"]) is int and 0 <= status["progress"] <= 255
        ))
    )
    if not (
        isinstance(data["address"], str) and data["address"]
        and data["state"] in ("live", "finished")
        and valid_status
        and type(data["turn"]) is int and 0 <= data["turn"] < 2**64
        and all(data[key] is None or (
            type(data[key]) is int and -(2**31) <= data[key] < 2**31
        ) for key in ("exit_code", "signal"))
        and (data["reason"] is None or isinstance(data["reason"], str))
        and type(data["reported"]) is bool
    ):
        raise ValueError("invalid terminal schema")
    return {key: data[key] for key in FIELDS}, True


def diagnostic(message, code):
    print(f"compact-status: {message}", file=sys.stderr)
    return code


def main(args):
    if args:
        return diagnostic("usage: compact-status.py < CAPTURED_GET_JSON", 64)
    try:
        result, terminal = compact(sys.stdin.buffer.read())
    except OSError:
        return diagnostic("cannot read stdin", 74)
    except ValueError as error:
        return diagnostic(str(error), 65)
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if terminal else diagnostic("error envelope in input; hc exit code unknown", 65)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
