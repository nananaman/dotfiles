"""Run the Chief task with real mise and fake process boundaries."""

import json
import os
from pathlib import Path
import shutil
import subprocess
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
        self.bin = self.root / "bin"
        self.bin.mkdir()
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
            "sys.exit(int(os.environ.get('CODEX_EXIT', '0')))\n"
        )
        boundary.chmod(0o755)
        for name in ("nono", "codex", "herdr-app"):
            (self.bin / name).symlink_to(boundary)
        self.env = {
            "HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin",
            "MISE_CONFIG_DIR": str(self.root / "config"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "MISE_DATA_DIR": str(self.root / "data"),
            "MISE_CACHE_DIR": str(self.root / "cache"),
            "MISE_STATE_DIR": str(self.root / "state"),
            "MISE_SYSTEM_CONFIG_DIR": str(self.root / "system"),
            "MISE_GLOBAL_CONFIG_FILE": str(self.root / "global.toml"),
            "MISE_NO_AUTO_UPDATE": "1", "MISE_COLOR": "0",
            "MISE_CEILING_PATHS": str(self.root),
            "CALL_LOG": str(self.log),
        }
        (self.root / "global.toml").write_text("")
        result = self.run_mise("trust", str(self.chief / "mise.toml"))
        self.assertEqual(result.returncode, 0, result.stderr)

    def run_mise(self, *args, cwd=None):
        return subprocess.run(
            [MISE, *args], cwd=cwd or self.chief, env=self.env,
            capture_output=True, text=True, timeout=60,
        )

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

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
        self.assertEqual(nono["args"], [
            "run", "--profile", "chouge-codex", "--workdir", str(self.chief),
            "--allow-cwd", "--read", str(self.home / ".local/state/herdr-core/default"),
            "--allow-unix-socket", str(self.home / ".local/state/herdr-core/default/default.sock"),
            "--allow-unix-socket", str(self.home / ".config/herdr-app/herdr-app.sock"),
            "--read-file", str(self.bin / "herdr-app"), "--", "codex",
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

    # Chief 専用設定を symlink 配置し、既存の設定とローカル状態は保護する。
    def test_deployment_links_only_the_task_and_preserves_conflicts(self):
        # Arrange
        repository = self.root / "repository"
        repository.mkdir()
        shutil.copy(ROOT / "mise.toml", repository / "mise.toml")
        source = repository / "home/chief-of-staff/mise.toml"
        source.parent.mkdir(parents=True)
        shutil.copy(ROOT / "home/chief-of-staff/mise.toml", source)
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
                    "bootstrap", "dotfiles", "apply", "~/chief-of-staff/mise.toml",
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
                self.assertEqual(local.read_text(), "preserve local state")


if __name__ == "__main__":
    unittest.main()
