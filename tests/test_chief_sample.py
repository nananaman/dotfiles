"""Offline sample summaries use fictional reports and explicit file inputs."""

from contextlib import redirect_stderr, redirect_stdout
import errno
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "home/chief-of-staff/inspect-sample.py"
FIXTURE = ROOT / "tests/fixtures/chief-sample.txt"
spec = importlib.util.spec_from_file_location("inspect_sample", SCRIPT)
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class ChiefSampleTests(unittest.TestCase):
    # 正常系: 指定した複数入力の観測事実だけを返し、接続や別コマンドを実行しない。
    def test_cli_preserves_observations_without_processes_sockets_or_private_data(self):
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
            [sys.executable, "-c", guarded, str(SCRIPT), str(FIXTURE), str(FIXTURE)],
            env={"PATH": "", "HC_SESSION": "default"},
            capture_output=True, text=True, timeout=10,
        )

        # Assert
        # 入力順と時刻・PID・UUID・frameを保ち、callerの無名symbolも明示する。
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stderr, "")
        reports = [json.loads(line) for line in run.stdout.splitlines()]
        self.assertEqual([report["sample"] for report in reports], [1, 2])
        self.assertEqual(reports[0], {
            "sample": 1, "pid": 101,
            "observed_at": "2001-02-03 04:05:06.789 +0900",
            "launched_at": "2001-02-03 01:02:03.456 +0900",
            "herdr_core_uuid": "11111111-2222-4333-8444-555555555555",
            "main_thread_frames": [
                {"frame": "start", "count": 1},
                {"frame": "herdr-core (unknown symbol)", "count": 2},
                {"frame": "__private_getcwd", "count": 1},
                {"frame": "__getcwd", "count": 1},
                {"frame": "open$NOCANCEL", "count": 1},
                {"frame": "__open_nocancel", "count": 1},
            ], "issues": [],
        })
        # pathや別threadを出力せず、現在状態や原因を付け加えない。
        self.assertNotIn("PRIVATE", run.stdout + run.stderr)
        self.assertNotIn("0x", run.stdout)
        self.assertNotIn("liveness", reports[0])
        self.assertNotIn("cause", reports[0])
        self.assertNotIn("permission", reports[0])

    # 異常系: 欠落・重複・未知形式を成功にせず、未知frameの生文字列を漏らさない。
    def test_incomplete_or_unrecognized_reports_have_unknown_fields_and_nonzero_exit(self):
        # Arrange
        text = FIXTURE.read_text()
        cases = [
            # 未対応のreport versionは全項目をunknownにする。
            (text.replace("Report Version:  7", "Report Version:  8"), "unsupported_format"),
            # PIDの不整合は同一性を保証しない。
            (text.replace("[101]", "[102]"), "pid"),
            # 不正な日付は単なる文字列として通さない。
            (text.replace("2001-02-03 04:", "2001-02-30 04:"), "observed_at"),
            # launch timeの欠落を明示する。
            (text.replace("Launch Time:", "Absent:"), "launched_at"),
            # herdr-core以外のUUIDで補完しない。
            (text.replace("+herdr-core (0)", "+other (0)"), "herdr_core_uuid"),
            # 重複した観測時刻から一方を選ばない。
            (text + "Date/Time:       2001-02-03 04:05:06.789 +0900\n", "observed_at"),
            # 主threadがなければ別threadのframeを使わない。
            (text.replace("com.apple.main-thread", "other-thread"), "main_thread_frames"),
            # 空の主threadを観測frameありとして扱わない。
            (text.replace(text.split("(serial)\n", 1)[1].split("    9 Thread_456", 1)[0], ""), "main_thread_frames"),
            # 未知symbolを省略せずunknownに置き換える。
            (text.replace("__open_nocancel", "PRIVATE_UNKNOWN"), "unrecognized_main_thread_frame"),
            # 分岐形式を読み飛ばして途中までのchainを成功にしない。
            (text.replace("    +             9", "    !             9"), "unrecognized_main_thread_frame"),
        ]
        with tempfile.TemporaryDirectory(prefix="chief-sample-test-") as directory:
            sample = Path(directory) / "PRIVATE_INPUT.txt"
            for content, issue in cases:
                with self.subTest(issue=issue):
                    sample.write_text(content)
                    out, err = io.StringIO(), io.StringIO()

                    # Act
                    with redirect_stdout(out), redirect_stderr(err):
                        code = reader.main([str(sample)])

                    # Assert
                    # 問題の項目・stderr・終了値を残し、privateな入力文字列を出さない。
                    report = json.loads(out.getvalue())
                    self.assertEqual(code, 1)
                    self.assertIn(issue, report["issues"])
                    self.assertIn(issue, err.getvalue())
                    self.assertIn("unknown", out.getvalue())
                    self.assertNotIn("PRIVATE", out.getvalue() + err.getvalue())

    # 異常系: 読取不能でも他の明示入力を処理し、エラーと非0を維持する。
    def test_read_errors_are_reported_without_paths_and_other_inputs_are_processed(self):
        # Arrange
        out, err = io.StringIO(), io.StringIO()
        real_open = os.open

        def denied(path, flags):
            if path == "PRIVATE_DENIED":
                raise PermissionError(errno.EPERM, "PRIVATE_REASON", path)
            return real_open(path, flags)

        # Act
        with patch.object(reader.os, "open", side_effect=denied):
            with redirect_stdout(out), redirect_stderr(err):
                code = reader.main(["PRIVATE_DENIED", str(FIXTURE)])

        # Assert
        # errnoは残すが例外内のpathやメッセージは出さない。
        reports = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(code, 1)
        self.assertEqual(reports[0]["issues"], ["read_error:PermissionError:errno=1"])
        self.assertTrue(all(reports[0][key] == "unknown" for key in reader.FIELDS))
        self.assertEqual(reports[1]["pid"], 101)
        self.assertIn("sample[1]: read_error:PermissionError:errno=1", err.getvalue())
        self.assertNotIn("PRIVATE", out.getvalue() + err.getvalue())

    # 異常系: 入力省略や通常file以外を読まず、UTF-8不正もエラーにする。
    def test_cli_rejects_no_input_nonfiles_and_invalid_encoding(self):
        # Arrange
        with tempfile.TemporaryDirectory(prefix="chief-sample-test-") as directory:
            invalid = Path(directory) / "PRIVATE_INVALID"
            invalid.write_bytes(b"\xff")
            fifo = Path(directory) / "PRIVATE_FIFO"
            os.mkfifo(fifo)
            cases = [([], 2, "usage:"), ([str(invalid)], 1, "invalid_utf8"),
                     ([str(fifo)], 1, "not_regular_file"),
                     ([str(Path(directory) / "PRIVATE_ABSENT")], 1, "FileNotFoundError")]
            for args, expected, message in cases:
                with self.subTest(message=message):
                    # Act
                    run = subprocess.run(
                        [sys.executable, str(SCRIPT), *args],
                        capture_output=True, text=True, timeout=10,
                    )

                    # Assert
                    # FIFOでも待機せず、stderrとexitで失敗を確認できる。
                    self.assertEqual(run.returncode, expected, run.stderr)
                    self.assertIn(message, run.stderr)
                    self.assertNotIn("PRIVATE", run.stdout + run.stderr)
                    if args:
                        report = json.loads(run.stdout)
                        self.assertTrue(all(report[key] == "unknown" for key in reader.FIELDS))


if __name__ == "__main__":
    unittest.main()
