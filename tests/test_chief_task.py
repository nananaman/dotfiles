"""Run the Chief task with real mise and fake process boundaries."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MISE = os.environ.get("MISE_BIN", shutil.which("mise"))


class ChiefTaskTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="chief task ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.home = self.root / "home with spaces"
        self.chief = self.home / "chief-of-staff"
        self.chief.mkdir(parents=True)
        shutil.copy(ROOT / "home/chief-of-staff/mise.toml", self.chief / "mise.toml")
        shutil.copy(ROOT / "home/chief-of-staff/nono-codex.py", self.chief / "nono-codex.py")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "python3").symlink_to(sys.executable)
        self.log = self.root / "calls.jsonl"
        boundary = self.bin / "boundary"
        boundary.write_text(
            f"#!{shutil.which('python3')}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "name = Path(sys.argv[0]).name\n"
            "with Path(os.environ['CALL_LOG']).open('a') as log:\n"
            "    log.write(json.dumps({'name': name, 'args': sys.argv[1:],\n"
            "        'cwd': os.getcwd(), 'inside_nono': os.environ.get('TEST_NONO')}) + '\\n')\n"
            "if name == 'nono':\n"
            "    command = sys.argv[sys.argv.index('--') + 1:]\n"
            "    os.environ['TEST_NONO'] = '1'\n"
            "    os.execvp(command[0], command)\n"
            "sys.stderr.write(os.environ.get('CODEX_STDERR', ''))\n"
            "sys.exit(int(os.environ.get('CODEX_EXIT', '0')))\n"
        )
        boundary.chmod(0o755)
        for name in ("nono", "codex", "herdr-app"):
            (self.bin / name).symlink_to(boundary)
        self.managed_bin = self.home / ".local/bin"
        self.managed_bin.mkdir(parents=True)
        (self.managed_bin / "codex").symlink_to(boundary)
        self.log_directory = self.root / "logs with spaces"
        self.log_directory.mkdir()
        self.env = {
            "HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin",
            "MISE_CONFIG_DIR": str(self.root / "config"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_RUNTIME_DIR": str(self.root / "runtime"),
            "MISE_DATA_DIR": str(self.root / "data"),
            "MISE_CACHE_DIR": str(self.root / "cache"),
            "MISE_STATE_DIR": str(self.root / "state"),
            "MISE_SYSTEM_CONFIG_DIR": str(self.root / "system"),
            "MISE_GLOBAL_CONFIG_FILE": str(self.root / "global.toml"),
            "MISE_NO_AUTO_UPDATE": "1", "MISE_COLOR": "0",
            "MISE_CEILING_PATHS": str(self.root),
            "CALL_LOG": str(self.log),
            "TMPDIR": str(self.log_directory),
        }
        (self.root / "global.toml").write_text("")
        result = self.run_mise("trust", str(self.chief / "mise.toml"))
        self.assertEqual(result.returncode, 0, result.stderr)

    def run_mise(self, *args, cwd=None, input=None):
        return subprocess.run(
            [MISE, *args], cwd=cwd or self.chief, env=self.env,
            capture_output=True, text=True, timeout=60, input=input,
        )

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    # 古いPATHとglobal pinがあっても、明示版をnono内のwrapperで選ぶ。
    def test_explicit_version_overrides_stale_path_and_global_pin(self):
        # Arrange
        (self.managed_bin / "codex").unlink()
        for name in ("codex", "dotfiles-exec"):
            shutil.copy(ROOT / "home/.local/bin" / name, self.managed_bin / name)
        (self.bin / "codex").unlink()
        for version in ("0.159.3", "0.166.0"):
            executable = self.root / "data/installs/codex" / version / "bin/codex"
            executable.parent.mkdir(parents=True)
            executable.write_text(
                f"#!{sys.executable}\n"
                "import os\n"
                "assert os.environ.get('TEST_NONO') == '1'\n"
                f"print('codex-cli {version}')\n"
            )
            executable.chmod(0o755)
            if version == "0.159.3":
                (self.bin / "codex").symlink_to(executable)
        (self.root / "global.toml").write_text('[tools]\ncodex = "0.159.3"\n')
        self.env["MISE_CODEX_VERSION"] = "0.166.0"
        self.env["MISE_BIN"] = MISE
        self.env["MISE_TASK_RUN_AUTO_INSTALL"] = "false"

        # Act
        result = subprocess.run(
            [sys.executable, str(self.chief / "nono-codex.py"), "--version"],
            cwd=self.chief, env=self.env, capture_output=True, text=True, timeout=60,
        )

        # Assert
        # PATH先頭の旧実体ではなく、指定版の結果を返す。
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "codex-cli 0.166.0")

    # nono のtraceだけを一意なprivate logへ移し、子のstderrと終了値は保持する。
    def test_private_log_paths_are_unique_and_child_errors_remain_visible(self):
        # Arrange
        self.env["CODEX_STDERR"] = "CHILD_STDERR_SENTINEL\n"
        self.env["CODEX_EXIT"] = "23"
        paths = []
        for args in ([], ["resume", "conversation with spaces"]):
            with self.subTest(args=args):
                # Act
                result = self.run_mise("run", "chief", *args)

                # Assert
                # 端末にはlogの場所と子のエラーを残し、silentにはしない。
                self.assertEqual(result.returncode, 23, result.stderr)
                nono = self.calls()[-2]["args"]
                self.assertIn("--log-file", nono)
                log = Path(nono[nono.index("--log-file") + 1])
                paths.append(log)
                self.assertEqual(log.parent, self.log_directory)
                self.assertTrue(log.is_file())
                self.assertEqual(log.stat().st_mode & 0o777, 0o600)
                self.assertEqual(result.stderr.count(f"nono log: {log}"), 1)
                self.assertIn("CHILD_STDERR_SENTINEL\n", result.stderr)
                self.assertNotIn("--silent", nono)
        self.assertEqual(len(set(paths)), 2)

    # 明示した session の state と socket だけを nono に許可する。
    def test_explicit_session_selects_its_own_state_and_socket(self):
        # Arrange
        self.env["HC_SESSION"] = "chief-overnight"

        # Act
        result = self.run_mise("run", "chief", "resume", "conversation with spaces")

        # Assert
        # default や state 全体への許可に広げない。
        self.assertEqual(result.returncode, 0, result.stderr)
        nono, codex = self.calls()
        state = self.home / ".local/state/herdr-core/chief-overnight"
        self.assertEqual(nono["args"][nono["args"].index("--read") + 1], str(state))
        self.assertEqual(nono["args"][nono["args"].index("--allow-unix-socket") + 1],
                         str(self.root / "runtime/herdr-core/chief-overnight.sock"))
        self.assertEqual(codex["inside_nono"], "1")

    # 未設定・空値・前後空白は hc の既定値と同じ session を指す。
    def test_empty_and_trimmed_sessions_keep_hc_defaults(self):
        # Arrange
        cases = [("", "default"), (" \t\r\n", "default"),
                 (" MyTest-1._ ", "MyTest-1._")]
        for raw, session in cases:
            with self.subTest(raw=raw):
                self.env["HC_SESSION"] = raw
                self.env["XDG_STATE_HOME"] = ""
                self.env["XDG_RUNTIME_DIR"] = ""

                # Act
                result = self.run_mise("run", "chief", "--version")

                # Assert
                # 空の XDG state でも HOME の session 配下だけを読む。
                self.assertEqual(result.returncode, 0, result.stderr)
                nono = self.calls()[-2]
                self.assertEqual(nono["args"][nono["args"].index("--read") + 1],
                                 str(self.home / ".local/state/herdr-core" / session))
                runtime = Path(f"/run/user/{os.getuid()}")
                socket_dir = (runtime / "herdr-core" if runtime.is_dir()
                              else self.home / ".local/state/herdr-core" / session)
                self.assertEqual(nono["args"][nono["args"].index("--allow-unix-socket") + 1],
                                 str(socket_dir / f"{session}.sock"))

    # path escape と未対応文字は nono や Codex を呼ぶ前に拒否する。
    def test_invalid_session_fails_before_process_boundaries(self):
        # Arrange
        cases = [".", "..", "../escape", "/tmp/escape", r"a\b", "a:b",
                 "a*b", "a?b", 'a"b', "a<b", "a>b", "a|b", "a\tb",
                 "\x1c", "a b", "日本語", "$(touch injected)"]
        for session in cases:
            with self.subTest(session=session):
                self.env["HC_SESSION"] = session

                # Act
                result = self.run_mise("run", "chief")

                # Assert
                # エラーは接続も core 起動も伴わない。
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("HC_SESSION", result.stderr)
                self.assertFalse(self.log.exists())
                self.assertFalse((self.chief / "injected").exists())

    # XDG state/runtime と socket 上書きは hc と同じ優先順位で選ぶ。
    def test_xdg_and_socket_overrides_grant_only_selected_paths(self):
        # Arrange
        self.env["HC_SESSION"] = "chief-overnight"
        state_home = self.root / "state with spaces"
        runtime = self.root / "runtime with spaces"
        self.env["XDG_STATE_HOME"] = str(state_home)
        self.env["XDG_RUNTIME_DIR"] = str(runtime)
        config = Path(self.env["XDG_CONFIG_HOME"]) / "herdr-core/config.toml"
        config.parent.mkdir(parents=True)
        config_socket = str(self.root / "config.sock")
        env_socket = str(self.root / "env.sock")
        cases = [
            ("", "", str(runtime / "herdr-core/chief-overnight.sock")),
            (f'socket = "{config_socket}"', "", config_socket),
            (f'socket = "{config_socket}"', env_socket, env_socket),
        ]
        for content, override, socket in cases:
            with self.subTest(socket=socket):
                config.write_text(content)
                self.env["HC_SOCKET"] = override

                # Act
                result = self.run_mise("run", "chief", "--version")

                # Assert
                # core の接続先と app の既存接続先以外は追加しない。
                self.assertEqual(result.returncode, 0, result.stderr)
                args = self.calls()[-2]["args"]
                self.assertEqual(args[args.index("--read") + 1],
                                 str(state_home / "herdr-core/chief-overnight"))
                self.assertEqual([args[i + 1] for i, arg in enumerate(args)
                                  if arg == "--allow-unix-socket"], [
                    socket, str(self.home / ".config/herdr-app/herdr-app.sock"),
                ])

    # 接続先を確定できない config は余分な許可を加えず停止する。
    def test_invalid_socket_config_fails_before_nono(self):
        # Arrange
        config = Path(self.env["XDG_CONFIG_HOME"]) / "herdr-core/config.toml"
        config.parent.mkdir(parents=True)
        for content in ('socket = "', 'socket = ""', 'socket = 42'):
            with self.subTest(content=content):
                config.write_text(content)

                # Act
                result = self.run_mise("run", "chief")

                # Assert
                # fallback で別の接続先を起動しない。
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("socket", result.stderr)
                self.assertFalse(self.log.exists())

    # 引数なしの実タスクは nono を経由して初回 prompt を渡す。
    def test_initial_launch_uses_nono_and_default_prompt(self):
        # Arrange
        self.env["CODEX_EXIT"] = "17"

        # Act
        result = self.run_mise("run", "chief")

        # Assert
        # 外側の権限と内側の実 argv、終了コードを維持する。
        self.assertEqual(result.returncode, 17, result.stderr)
        nono, codex = self.calls()
        self.assertEqual(nono["name"], "nono")
        log_path = nono["args"][nono["args"].index("--log-file") + 1]
        self.assertEqual(nono["args"], [
            "run", "--profile", "chouge-codex", "--log-file", log_path,
            "--suppress-save-prompt", str(self.home / ".nix-profile"),
            "--workdir", str(self.chief),
            "--allow-cwd", "--read", str(self.home / ".local/state/herdr-core/default"),
            "--allow-unix-socket", str(self.root / "runtime/herdr-core/default.sock"),
            "--allow-unix-socket", str(self.home / ".config/herdr-app/herdr-app.sock"),
            "--read-file", str(self.bin / "herdr-app"), "--", str(self.managed_bin / "codex"),
            "--no-daemon", "--sandbox", "danger-full-access", "--ask-for-approval", "never",
            "-C", str(self.chief),
            "AGENTS.md と hc --skill を読み、Chief of Staff として依頼を受けてください。",
        ])
        self.assertEqual(codex["name"], "codex")
        self.assertEqual(codex["inside_nono"], "1")
        self.assertEqual(codex["cwd"], str(self.chief))
        self.assertEqual(codex["args"], nono["args"][nono["args"].index("--") + 2:])

    # 再開と任意の起動引数は初回 prompt を加えず、一引数内の空白を保持する。
    def test_explicit_arguments_reach_codex_without_default_prompt(self):
        # Arrange
        cases = [
            ["resume", "019a5000-1234-7890-abcd-123456789abc"],
            ["resume"],
            ["resume", "conversation with spaces", "追加の指示 with spaces"],
            ["-m", "gpt-6.1-sol", "-c", 'model_reasoning_effort="high"',
             "literal $(touch injected) 'quotes' ; with spaces"],
        ]
        for args in cases:
            with self.subTest(args=args):
                # Act
                result = self.run_mise("run", "chief", *args)

                # Assert
                # 通常の Codex 引数を shell 再評価せず転送する。
                self.assertEqual(result.returncode, 0, result.stderr)
                nono = self.calls()[-2]["args"]
                self.assertEqual([nono[i + 1] for i, arg in enumerate(nono)
                                  if arg == "--suppress-save-prompt"],
                                 [str(self.home / ".nix-profile")])
                codex = self.calls()[-1]
                self.assertEqual(codex["inside_nono"], "1")
                self.assertEqual(codex["args"], [
                    "--no-daemon", "--sandbox", "danger-full-access",
                    "--ask-for-approval", "never", "-C", str(self.chief), *args,
                ])
                self.assertFalse((self.chief / "injected").exists())

    # nono がなければ起動を失敗させ、Codex を直接起動しない。
    def test_missing_nono_fails_without_launching_codex(self):
        # Arrange
        (self.bin / "nono").unlink()

        # Act
        result = self.run_mise("run", "chief")

        # Assert
        # nono 不在でも fake Codex は PATH にあるが呼ばれない。
        self.assertEqual(result.returncode, 127, result.stderr)
        self.assertIn("nono", result.stderr)
        self.assertFalse(self.log.exists())

    # 既存の3 symlinkだけで scriptを参照し、競合とローカル状態を保護する。
    def test_deployment_links_only_the_task_and_preserves_conflicts(self):
        # Arrange
        repository = self.root / "repository"
        repository.mkdir()
        shutil.copy(ROOT / "mise.toml", repository / "mise.toml")
        source = repository / "home/chief-of-staff/mise.toml"
        source.parent.mkdir(parents=True)
        shutil.copy(ROOT / "home/chief-of-staff/mise.toml", source)
        for name in ("AGENTS.md", "README.md", "nono-codex.py", "inspect-sample.py", "compact-status.py"):
            shutil.copy(ROOT / "home/chief-of-staff" / name, source.parent / name)
        (self.chief / "nono-codex.py").unlink()
        target = self.chief / "mise.toml"
        local = self.chief / ".codex/local-state"
        local.parent.mkdir()
        local.write_text("preserve local state")
        self.run_mise("trust", str(repository / "mise.toml"))
        for existing in (False, True):
            with self.subTest(existing=existing):
                target.unlink()
                if existing:
                    target.write_text("local mise configuration")

                # Act
                result = self.run_mise(
                    "bootstrap", "dotfiles", "apply", "~/chief-of-staff/AGENTS.md",
                    "~/chief-of-staff/README.md", "~/chief-of-staff/mise.toml",
                    cwd=repository,
                )

                # Assert
                # 競合は失敗し、新規配置だけが symlink になる。
                if existing:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(target.is_symlink())
                    self.assertEqual(target.read_text(), "local mise configuration")
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(target.is_symlink())
                    self.assertEqual(target.resolve(), source)
                    self.assertFalse((self.chief / "nono-codex.py").exists())
                    # 既存3リンクだけで読取scriptへ到達し、nonoやCodexを呼ばない。
                    before = self.calls() if self.log.exists() else []
                    inspected = self.run_mise(
                        "run", "inspect-sample", str(ROOT / "tests/fixtures/chief-sample.txt"),
                    )
                    self.assertEqual(inspected.returncode, 0, inspected.stderr)
                    self.assertEqual(json.loads(inspected.stdout)["pid"], 101)
                    self.assertEqual(self.calls() if self.log.exists() else [], before)
                    self.assertFalse((self.chief / "inspect-sample.py").exists())
                    # 同じ3リンクでstdin投影へ到達し、追加コマンドを呼ばない。
                    observed = {
                        "address": "t7", "state": "live", "status": {"state": "blocked", "kind": "auth"},
                        "turn": 0, "exit_code": None, "signal": None, "reason": None, "reported": False,
                    }
                    compacted = self.run_mise(
                        "--quiet", "run", "compact-status",
                        input=json.dumps({**observed, "argv": ["PRIVATE"], "screen": "PRIVATE"}),
                    )
                    self.assertEqual(compacted.returncode, 0, compacted.stderr)
                    self.assertEqual(json.loads(compacted.stdout), observed)
                    self.assertEqual(compacted.stderr, "")
                    self.assertEqual(self.calls() if self.log.exists() else [], before)
                    self.assertFalse((self.chief / "compact-status.py").exists())
                    launched = self.run_mise("run", "chief", "--version")
                    self.assertEqual(launched.returncode, 0, launched.stderr)
                    self.assertEqual(self.calls()[-1]["inside_nono"], "1")
                    self.assertEqual(self.calls()[-1]["cwd"], str(self.chief))
                    args = self.calls()[-1]["args"]
                    self.assertEqual(args[args.index("-C") + 1], str(self.chief))
                self.assertEqual(local.read_text(), "preserve local state")


if __name__ == "__main__":
    unittest.main()
