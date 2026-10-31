"""Cross-client compatibility contracts for the declared skill distribution."""
from pathlib import Path
import re
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "d25aec07e3fd2695165e274330afa7d183ba3e6a"
USER_MAINTENANCE_PIN = "8f1e4a66cd5334a00f4e899b2ec8c200a2003f91"


class AgentDistributionContractTest(unittest.TestCase):
    def test_legacy_apm_view_has_no_live_paths_into_removed_source(self):
        manifest = (ROOT / "home/.apm/apm.yml").read_text()
        pins = dict(re.findall(r"^    - nananaman/skills/plugin/skills/([a-z0-9-]+)#([0-9a-f]{40})$", manifest, re.M))
        routing = tomllib.loads((ROOT / "agent-plugins.toml").read_text())["codex_routing"]

        self.assertEqual(24, len(pins))
        self.assertEqual(set(pins), set(routing["legacy_apm_skills"]))
        self.assertEqual(BASELINE, pins["excalidraw"])
        self.assertEqual(USER_MAINTENANCE_PIN, pins.pop("skill-maintenance"))
        self.assertTrue(all(ref == BASELINE for ref in pins.values()))
        self.assertNotIn("path: ~/ghq/github.com/nananaman/skills/plugin/skills/", manifest)

    def test_existing_apm_targets_and_unrelated_dependencies_remain(self):
        manifest = (ROOT / "home/.apm/apm.yml").read_text()
        target_block = re.search(r"^targets:\n((?:  - [^\n]+\n)+)", manifest, re.M).group(1)

        self.assertEqual(["claude", "codex", "agent-skills"], re.findall(r"  - (.+)", target_block))
        self.assertIn("path: ~/.apm/packages/textlint-ai", manifest)
        self.assertEqual(5, len(re.findall(r"stablyai/orca/skills/[^\s]+#af82126058de7ff0864f4cfb0ed347914595de91", manifest)))
        self.assertIn("humanlayer/skills/plugins/show-me/skills/show-me#3c2629142c5d437428269b1b722b08c0b87f574d", manifest)

    def test_shared_instructions_keep_other_clients_on_their_existing_entry_points(self):
        instructions = (ROOT / "home/.agents/AGENTS.md").read_text()

        self.assertIn("Codexの通常の開発は `pstack:poteto-mode`", instructions)
        self.assertIn("Codex以外では、コード、設定", instructions)
        self.assertIn("従来どおり `implement`", instructions)
        self.assertIn("Codex以外では、skillのレビュー・監査", instructions)
        self.assertIn("how explorer: gpt-6.1-sol @high", instructions)
        self.assertIn("how explainer: gpt-6.1-sol @high", instructions)
        self.assertIn("モデル実行は累計20分を上限", instructions)


if __name__ == "__main__":
    unittest.main()
