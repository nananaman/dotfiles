---
name: code-review
description: Run a strict, budget-conscious code review for the current diff, branch, commit, or PR. Use when the user asks for code review, PR review, autoreview, or a second-model review.
---

# Code Review

Run a strict but cost-conscious review of the current change. This skill always reviews correctness, security, and maintainability. It also applies a high bar for structural quality: spaghetti growth, abstraction quality, file-size creep, ownership boundaries, and opportunities to make the implementation dramatically simpler without changing behavior.

## Default Behavior

- Prefer lightweight review models to control cost.
- Prefer `pi` when available, using `opencode-go/deepseek-v4-flash`.
- Use `sonnet` when running through Claude Code.
- Use a mini / spark style coding model when running through Codex.
- Escalate to a more expensive model only when the user explicitly asks or the lightweight model cannot evaluate the change with enough confidence.
- Treat review output as advisory. Verify every accepted finding by reading the relevant code before applying a fix.
- Report only high-confidence, actionable findings. Do not report cosmetic nits, style preferences, or speculative risks.

Output language is intentionally not specified here. It is controlled by the global agent instructions in `agents/AGENTS.md`.

## Recommended Commands

Use the bundled helper.

```bash
apm/skills/code-review/scripts/code-review --mode branch --base origin/main
```

If the branch has an open PR, use the PR's actual base.

```bash
base=$(gh pr view --json baseRefName --jq .baseRefName)
apm/skills/code-review/scripts/code-review --mode branch --base "origin/$base"
```

Review dirty local work:

```bash
apm/skills/code-review/scripts/code-review --mode local
```

Review a single commit:

```bash
apm/skills/code-review/scripts/code-review --mode commit --commit HEAD
```

Force a specific engine:

```bash
apm/skills/code-review/scripts/code-review --engine pi --mode branch --base origin/main
apm/skills/code-review/scripts/code-review --engine claude --mode branch --base origin/main
apm/skills/code-review/scripts/code-review --engine codex --mode branch --base origin/main
```

## Model Policy

Defaults are intentionally lightweight.

| engine | default model | notes |
| --- | --- | --- |
| `pi` | `opencode-go/deepseek-v4-flash` | First choice. Uses low thinking by default. |
| `claude` | `sonnet` | Use when Claude Code CLI is available. |
| `codex` | `gpt-5.4-mini` | Override with `CODE_REVIEW_CODEX_MODEL` if the local Codex install exposes a different lightweight model. |

Environment overrides:

```bash
CODE_REVIEW_ENGINE=pi
CODE_REVIEW_PI_MODEL=opencode-go/deepseek-v4-flash
CODE_REVIEW_PI_THINKING=low
CODE_REVIEW_CLAUDE_MODEL=sonnet
CODE_REVIEW_CODEX_MODEL=gpt-5.4-mini
```

## Always-On Strict Review Rubric

Apply these checks every time. They are not optional.

- Correctness regressions, broken runtime paths, migration/order mistakes.
- Security regressions, secret exposure, permission-boundary breaks.
- Structural code-quality regressions.
- Spaghetti growth: ad-hoc conditionals, special-case branches, or local exceptions bolted onto existing flows.
- Abstraction quality: thin wrappers, unnecessary indirection, and magical generic mechanisms.
- Code judo: ways to preserve behavior while deleting concepts, branches, helper layers, or incidental complexity.
- Ownership boundaries: whether logic lives in the right layer, package, module, or helper.
- Typed boundaries: whether casts, optionality, `any`, or `unknown` hide the real invariant.
- File size and decomposition: especially changes that push a file past 1000 lines.
- Orchestration quality: avoidable sequential work or non-atomic updates that make the implementation harder to reason about.

## Output Expectations

When findings exist, prefer this shape:

```md
## Findings

### [severity] title
- Target: path:line
- Problem: what breaks or what becomes harder to maintain
- Evidence: facts from the diff, existing code, or documented behavior
- Suggested fix: the smallest appropriate fix at the right ownership boundary
```

When no actionable findings exist, the review must explicitly say that there are no accepted/actionable findings, in the language required by the active agent instructions.

## Closeout Report

When reporting back to the user, include:

- Review command used.
- Engine and model used.
- Tests/proof run.
- Findings accepted or rejected, with brief reasons.
- The clean review result, or why a remaining finding was consciously rejected.

## Attribution

This local skill is inspired by:

- `openclaw/agent-skills` `autoreview` workflow ideas, MIT License.
- `cursor/plugins` `cursor-team-kit/skills/thermo-nuclear-code-quality-review` review rubric ideas, MIT License.

See `NOTICE.md` and `LICENSE` in this skill directory.
