# Lab-LaunchPad-AI-SDK

## Installed plugin: founder-os (from marketplace `rahlplx/solo-founder-wingman`)

This repo has the `founder-os` plugin installed at **project scope**, via
`.claude/settings.json`:
- `extraKnownMarketplaces.solo-founder-wingman` registers the GitHub source
  `rahlplx/solo-founder-wingman`. Note: the marketplace's own declared name
  (inside its `marketplace.json`) is `lab-launchpad-ai-sdk`, not the key
  above — that declared name is what the `plugin@marketplace` install/update
  commands actually key off, e.g. `claude plugin install
  founder-os@lab-launchpad-ai-sdk`.
- `enabledPlugins."founder-os@lab-launchpad-ai-sdk"` enables it.

It provides:
- **21 skills** — `add-page`, `audit-summary`, `build-feature`, `debug-seb`,
  `fix-bug`, `founding-prompt`, `git-save-points`, `handoff`, `hire-agent`,
  `integrate-service`, `map-architecture`, `multi-model-review`,
  `refactor-cleanup`, `refactor-safely`, `review-code`, `security-audit`,
  `ship-checklist`, `show-reference`, `validate-demand`, `verify-path`,
  `weekly-plan` — a lifecycle library for non-technical solo founders taking
  a product from idea to shipped.
- **3 agents** — `qa-tester`, `code-critic`, `security-reviewer`.
- **A policy-engine safety layer** (`PreToolUse`/`PostToolUse`/`Stop` hooks)
  that intercepts destructive, secret-leaking, or cost-risky agent actions
  before execution. It is regex/pattern-based and has documented blind
  spots (see the upstream repo's `audit/` reports) — treat it as a
  safety net, not a substitute for review.
- **8 MCP server integrations** — supabase, stripe, vercel, sentry,
  posthog, playwright, github, context7.

First-time contributors: opening this repo in Claude Code will prompt a
one-time workspace-trust confirmation before the committed hooks/plugin are
allowed to run. This is expected — accept it once per machine. If the
plugin ever shows as "not installed" in a fresh clone, run:
`claude plugin install founder-os@lab-launchpad-ai-sdk --scope project`

## Automation: every-7-prompts improvement review

`.claude/hooks/query-counter.sh` is a `UserPromptSubmit` hook that counts
prompts in a local, gitignored, cumulative counter
(`.claude/state/query-count.txt`). Every 7th prompt, it injects context
telling Claude to run the process defined in
`.claude/skills/improvement-review/SKILL.md`: gather real evidence (run
tests/lints/benchmarks where they exist), identify concrete evidence-backed
improvement candidates, rank alternatives with tradeoffs, and — if there's
something real to propose — open a PR (never auto-merged) with a dated
report, in this repo and/or in `rahlplx/solo-founder-wingman`, whichever has
actionable findings.

**Known limitation (by design):** the counter is a local file, not
committed to git. It persists across turns/sessions within the same
container, but resets to 0 if the container is fully reclaimed. We
intentionally do not auto-commit it on every message to avoid commit spam —
this is a documented tradeoff, not an oversight.
