"""Cross-client compatibility contracts for the declared skill distribution."""
from pathlib import Path
import re
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
PSTACK_DEPENDENCY = """    - git: michael-denyer/pstack-claude
      path: plugins/pstack
      ref: 513c0886b79abb04065293581a4ef7e70049e4f2
      targets: [codex]
"""
MAINTENANCE_REF = "nananaman/skills/plugin/skills/skill-maintenance#3e067f262e8fb97cc7333cd12ac35ff209f3643e"
SUPPLEMENT = {"apm-usage", "apple-container", "chouge-changelog", "chouge-git", "chouge-writing",
              "excalidraw", "nono-sandbox-maintenance", "sakura-cloud-eventbus", "sakura-cloud-webaccel",
              "sakura-cloud-workflows", "skill-workbench", "test-writing-style", "update-skills"}
RETIRED_APM = {"create-pr", "draft-prd", "polish-prd", "draft-design-doc",
               "polish-design-doc", "task-breakdown", "create-plan", "review-plan", "review-diff-code",
               "implement", "tdd", "grilling", "handoff"}


class AgentDistributionContractTest(unittest.TestCase):
    def test_apm_owns_fixed_pstack_and_current_complements_without_legacy_view(self):
        manifest = (ROOT / "home/.apm/apm.yml").read_text()
        local_skills = set(re.findall(r"^    - path: ~/ghq/github.com/nananaman/skills/plugin/skills/([a-z0-9-]+)$", manifest, re.M))

        self.assertEqual(SUPPLEMENT, local_skills)
        self.assertIn(PSTACK_DEPENDENCY, manifest)
        self.assertIn("    - " + MAINTENANCE_REF, manifest)
        self.assertFalse(any("plugin/skills/" + name + "\n" in manifest for name in RETIRED_APM))
        tasks = tomllib.loads((ROOT / "mise.toml").read_text())["tasks"]
        self.assertEqual("apm install -g --dry-run", tasks["apm-plan"]["run"])
        self.assertEqual(["python3 scripts/apm-pstack-hooks.py --apply --if-installed", "apm install -g", "python3 scripts/apm-pstack-hooks.py --apply"], tasks["apm-sync"]["run"])
        self.assertFalse((ROOT / "agent-plugins.toml").exists())

    def test_existing_apm_targets_and_unrelated_dependencies_remain(self):
        manifest = (ROOT / "home/.apm/apm.yml").read_text()
        target_block = re.search(r"^targets:\n((?:  - [^\n]+\n)+)", manifest, re.M).group(1)

        self.assertEqual(["claude", "codex", "agent-skills"], re.findall(r"  - (.+)", target_block))
        self.assertIn("path: ~/.apm/packages/textlint-ai", manifest)
        self.assertEqual(5, len(re.findall(r"stablyai/orca/skills/[^\s]+#af82126058de7ff0864f4cfb0ed347914595de91", manifest)))
        self.assertIn("humanlayer/skills/plugins/show-me/skills/show-me#3c2629142c5d437428269b1b722b08c0b87f574d", manifest)

    def test_shared_instructions_are_common_and_models_have_their_own_source(self):
        instructions = (ROOT / "home/.agents/AGENTS.md").read_text()
        models = (ROOT / "home/.codex/pstack-models.md").read_text()

        self.assertIn("同じ配布元の実体を確認して対応付け", instructions)
        for obsolete in ("Codex", "Claude", "Pi等", "`implement`", "旧24件", "初期pilot", "gpt-6.1-sol"):
            self.assertNotIn(obsolete, instructions)
        self.assertIn("how explorer: gpt-6.1-sol @high", models)
        self.assertIn("how explainer: gpt-6.1-sol @high", models)
        self.assertIn("default effort: high", models)
        self.assertIn("session hook: on", models)


if __name__ == "__main__":
    unittest.main()
