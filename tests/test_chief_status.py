"""Captured hc JSON is projected offline without inferring command success."""

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "home/chief-of-staff/compact-status.py"
CONTRACT_FIELDS = ("address", "state", "status", "turn", "exit_code", "signal", "reason", "reported")
spec = importlib.util.spec_from_file_location("compact_status", SCRIPT)
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class ChiefStatusTests(unittest.TestCase):
    def setUp(self):
        self.value = {
            "address": "t7", "state": "live",
            "status": {"app": "codex", "state": "working", "progress": 0,
                       "msg": "", "title": "作業", "kind": None, "future": False},
            "turn": 0, "exit_code": None, "signal": None, "reason": None, "reported": False,
            "argv": ["PRIVATE_ARGV"], "screen": "PRIVATE_SCREEN", "cwd": "PRIVATE_CWD",
        }

    def run_cli(self, raw=None, args=(), env=None):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            input=raw if raw is not None else json.dumps(self.value).encode(),
            env={"PATH": "", "HC_SOCKET": "PRIVATE_SOCKET", "HC_SESSION": "unused", **(env or {})},
            capture_output=True, timeout=10,
        )

    # 正常系: status全体とnull・0・falseを保ち、端末の完了や成功を推定しない。
    def test_observations_are_projected_without_inventing_completion(self):
        # Arrange
        for state in ("working", "blocked", "error", None):
            with self.subTest(state=state):
                self.value["status"] = {**self.value["status"], "state": state} if state else None
                if state == "blocked":
                    self.value["status"].update(kind="auth", msg="person needed")
                if state is None:
                    self.value.update(state="finished", exit_code=0, reason="exited")

                # Act
                run = self.run_cli()

                # Assert
                # 必須8項目とstatus内の追加項目を正確に保ち、他の情報を表示しない。
                self.assertEqual(run.returncode, 0, run.stderr)
                self.assertEqual(json.loads(run.stdout), {key: self.value[key] for key in CONTRACT_FIELDS})
                self.assertEqual(run.stderr, b"")
                self.assertNotIn(b"PRIVATE", run.stdout)

    # 異常系: error envelopeは内容を保つが、JSONから元hcの終了値を推定しない。
    def test_error_envelope_remains_an_error_with_unknown_upstream_exit(self):
        # Arrange
        error = {"error": {"kind": "blocked", "message": "needs a person", "hint": "read once"}}

        # Act
        run = self.run_cli(json.dumps(error).encode())

        # Assert
        # filterの非0と元CLIの終了値不明を区別する。
        self.assertEqual(run.returncode, 65)
        self.assertEqual(json.loads(run.stdout), error)
        self.assertEqual(run.stderr, b"compact-status: error envelope in input; hc exit code unknown\n")

    # 異常系: 欠落・不正JSON・schema不備・空入力を成功扱いしない。
    def test_invalid_json_schema_and_missing_fields_are_not_success(self):
        # Arrange
        cases = [b"", b"PRIVATE_NOT_JSON", b"\xff", b"[]", b'{"x":1,"x":2}', b'{"x":NaN}']
        cases += [json.dumps({k: v for k, v in self.value.items() if k != key}).encode() for key in CONTRACT_FIELDS]
        cases += [json.dumps({**self.value, key: bad}).encode() for key, bad in (
            ("status", {"state": False}), ("status", "working"), ("turn", False),
            ("turn", -1), ("exit_code", False), ("reported", 0), ("signal", False),
            ("state", "done"), ("address", None),
        )]
        for raw in cases:
            with self.subTest(raw=raw[:30]):
                # Act
                run = self.run_cli(raw)

                # Assert
                # 生入力を出さず、filter固有の解析失敗として返す。
                self.assertEqual(run.returncode, 65, run.stderr)
                self.assertEqual(run.stdout, b"")
                self.assertIn(b"compact-status:", run.stderr)
                self.assertNotIn(b"PRIVATE", run.stderr)

    # 異常系: 指数overflowはterminal/error envelopeの深さによらず出力前に拒否する。
    def test_overflow_numbers_fail_before_any_output(self):
        # Arrange
        for number in ("1e309", "-1e309"):
            for future in (number, '{"nested":[' + number + ']}'):
                for envelope in (False, True):
                    with self.subTest(number=number, future=future, envelope=envelope):
                        value = {"error": {"future": "NUMBER"}} if envelope else {
                            **self.value, "status": {**self.value["status"], "future": "NUMBER"},
                        }
                        raw = json.dumps(value).replace('"NUMBER"', future).encode()

                        # Act
                        run = self.run_cli(raw)

                        # Assert
                        # filter固有の失敗で、Infinityや部分的なJSONをstdoutへ出さない。
                        self.assertEqual(run.returncode, 65, run.stderr)
                        self.assertEqual(run.stdout.decode("utf-8", errors="strict"), "")
                        self.assertIn("compact-status:", run.stderr.decode("utf-8", errors="strict"))
                        self.assertNotIn(b"Traceback", run.stderr)

    # 異常系: lone surrogateは値・nested・keyともstdout encodingに依存せず出力前に拒否する。
    def test_lone_surrogates_fail_before_any_output(self):
        # Arrange
        for surrogate in ("\ud800", "\udc80"):
            for future in (surrogate, {"nested": [surrogate]}, {surrogate: "value"}):
                for envelope in (False, True):
                    for encoding in ("utf-8:strict", "utf-8:surrogateescape", "utf-8:surrogatepass"):
                        with self.subTest(future=repr(future), envelope=envelope, encoding=encoding):
                            value = {"error": {"future": future}} if envelope else {
                                **self.value, "status": {**self.value["status"], "future": future},
                            }
                            raw = json.dumps(value).encode()

                            # Act
                            run = self.run_cli(raw, env={"PYTHONIOENCODING": encoding})

                            # Assert
                            # raw surrogate bytesもtracebackも出さず、filterの診断だけを返す。
                            self.assertEqual(run.returncode, 65, run.stderr)
                            self.assertEqual(run.stdout.decode("utf-8", errors="strict"), "")
                            self.assertIn("compact-status:", run.stderr.decode("utf-8", errors="strict"))
                            self.assertNotIn(b"Traceback", run.stderr)

    # 正常系: 有限float・Unicode・surrogate pairと端末の観測値をそのまま保持する。
    def test_finite_unicode_and_terminal_observations_survive_strict_output(self):
        # Arrange
        future = {"float": 1.25e100, "negative": -1.25e100, "zero": 0, "null": None,
                  "false": False, "日本語": ["作業", "é", "😀"]}
        for status_state in ("working", "blocked", "error"):
            for exit_code, signal in ((None, None), (23, None), (None, 15)):
                with self.subTest(status=status_state, exit_code=exit_code, signal=signal):
                    value = {**self.value, "state": "finished" if exit_code or signal else "live",
                             "exit_code": exit_code, "signal": signal,
                             "status": {**self.value["status"], "state": status_state, "future": future}}
                    raw = json.dumps(value).encode()  # emojiは正規surrogate pairとして入力する。

                    # Act
                    run = self.run_cli(raw)

                    # Assert
                    # strict UTF-8/JSONで読め、8項目とstatus全体を保持する。元hc exit/timeoutは推定しない。
                    self.assertEqual(run.returncode, 0, run.stderr)
                    text = run.stdout.decode("utf-8", errors="strict")
                    self.assertEqual(json.loads(text, parse_constant=self.fail),
                                     {key: value[key] for key in CONTRACT_FIELDS})
                    self.assertIn("作業", text)
                    self.assertIn("😀", text)
                    self.assertEqual(run.stderr, b"")

    # 境界: 環境のsocket指定に触れず、stdinだけを使ってprocessや接続を増やさない。
    def test_cli_does_not_start_processes_or_connect_to_sockets(self):
        # Arrange
        guarded = """
import runpy, sys
def guard(event, args):
    if event.startswith('socket.') or event in ('subprocess.Popen', 'os.system', 'os.exec', 'os.posix_spawn'):
        raise RuntimeError('forbidden process or socket')
sys.addaudithook(guard)
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name='__main__')
"""

        # Act
        run = subprocess.run(
            [sys.executable, "-c", guarded, str(SCRIPT)], input=json.dumps(self.value).encode(),
            env={"PATH": "", "HC_SOCKET": "PRIVATE_SOCKET"},
            capture_output=True, timeout=10,
        )

        # Assert
        # hcの存在や接続先に依存せず、投影だけが成功する。
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(json.loads(run.stdout)["status"], self.value["status"])
        self.assertEqual(run.stderr, b"")

    # 異常系: 引数を入力pathや接続先として解釈せず、読取失敗も非0で返す。
    def test_arguments_and_stdin_read_failure_return_frontend_errors(self):
        # Arrange
        out, err = io.StringIO(), io.StringIO()
        stdin = Mock()
        stdin.buffer.read.side_effect = OSError("PRIVATE_REASON")

        # Act
        run = self.run_cli(args=("unused-session", "t7"))
        with patch.object(sys, "stdin", stdin), redirect_stdout(out), redirect_stderr(err):
            code = reader.main([])

        # Assert
        # 元hcの終了値とは別のusage/readエラーであり、入力内容は漏らさない。
        self.assertEqual(run.returncode, 64)
        self.assertEqual(run.stdout, b"")
        self.assertIn(b"usage:", run.stderr)
        self.assertEqual(code, 74)
        self.assertEqual(out.getvalue(), "")
        self.assertEqual(err.getvalue(), "compact-status: cannot read stdin\n")


if __name__ == "__main__":
    unittest.main()
