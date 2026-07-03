---
name: improvement-review
description: Triggered every 7th prompt by .claude/hooks/query-counter.sh (or invoked manually). Produces an evidence-backed improvement-options report and, where warranted, a PR — for this repo and/or rahlplx/solo-founder-wingman.
---

# Improvement Review

## When this runs
- Automatically: `.claude/hooks/query-counter.sh` injects additionalContext
  on every 7th `UserPromptSubmit` in this project, instructing Claude to
  follow this process.
- Manually: a user or agent can also invoke this process directly by name.

## Scope: which repo(s)
Evaluate **both** repos each time this runs:
1. This repo (`Lab-LaunchPad-AI-SDK`) — the product being built.
2. `rahlplx/solo-founder-wingman` (the `founder-os` plugin's upstream repo),
   read via its public GitHub source (raw file fetch / GitHub API) rather
   than a full local clone, unless a local clone is already available in
   this session.

Only open a PR in a repo if there is a real, evidence-backed finding worth
proposing there. It is expected and fine for a run to produce a PR in one
repo and nothing in the other, or nothing in either.

## Process
1. **Gather evidence — do not speculate.**
   - This repo: run whatever test/lint/build tooling exists (check for a
     `package.json`, CI config, etc. — this may still be sparse). If no
     tooling exists yet, this step is limited to static repo inspection
     (structure, obvious gaps, missing CI/lint/tests) — say so explicitly
     rather than inventing results.
   - `rahlplx/solo-founder-wingman` (`founder-os/`): it has a real test
     suite. Its `package.json` defines:
     `npm run test` → runs, in order: `test:core`, `test:schema`,
     `test:claude-code`, `test:opencode`, `test:hooks`, `test:settings`,
     `test:redos-guard`, `test:audit-log`, `test:repo-scans`,
     `test:lint-harness`, `test:lint-prd`, `test:ci-drift`, then
     `check:version-sync`. Individual runners live in `founder-os/tests/`
     (e.g. `run-core-engine-tests.js`, `run-policy-tests.js`,
     `run-hook-tests.js`, `run-schema-validation-tests.js`, etc. — 14
     scripts total, some `tsx`-based). There's also
     `founder-os/bin/scan-secrets.js`, `bin/lint-harness.js`,
     `bin/check-js-syntax.js`, and `npm run audit:deps` (`npm audit`).
     Actually run the relevant scripts and capture real pass/fail output —
     never cite a result you didn't actually produce.
2. **Identify candidates.** From the evidence, list concrete, specific
   improvement candidates (not vague "improve code quality" items). Each
   candidate must cite the evidence that motivates it.
3. **Rank alternatives with tradeoffs.** For each candidate, note at least
   one alternative approach and the tradeoff (effort, risk, blast radius,
   reversibility). Recommend one.
4. **Decide what to ship this run.** Not every run needs a PR. If nothing
   rises above trivial/speculative, say so explicitly in the report and
   skip the branch/commit/PR steps for that repo.
5. **Write the report** (a recommendations report, not necessarily a code
   change):
   - This repo: `docs/improvements/YYYY-MM-DD.md`.
   - `solo-founder-wingman`: match its existing `audit/issues/` convention
     instead of inventing a new structure. That directory's files
     (`FEATURE-001.md`, `PLATFORM-001.md`, `SAFETY-001.md`) use plain
     Markdown, no frontmatter, following this shape:
     ```
     # <CATEGORY>-<NNN>: <Short title>

     ## Core Problem
     <what's wrong / the gap, grounded in evidence>

     ## Key Solutions Proposed
     <ranked options with tradeoffs, one clearly recommended>

     ## Implementation Checklist
     <concrete next steps>
     ```
     Pick the next sequential number for whichever category fits (e.g.
     `IMPROVEMENT-001.md` if the finding doesn't fit `FEATURE`/`PLATFORM`/
     `SAFETY`, or continue an existing category's sequence if it does).
   Each report must include: date, evidence commands actually run and
   their real output/summary, ranked candidates with tradeoffs, and the
   single recommendation per candidate.
6. **Branch, commit, push, open PR** (per repo with real findings):
   - Branch name: `improvement-review/YYYY-MM-DD`.
   - Commit the report file(s) only — this is a recommendations report,
     not necessarily a code change. Don't bundle unrelated edits.
   - Push, then open a PR (GitHub MCP tools, or `gh` if available). PR
     body = report summary.
   - **Never auto-merge.** This process only proposes; a human approves.

## Non-goals / guardrails
- Never modify `.claude/state/query-count.txt` as part of "shipping" a fix
  — that file is deliberately local/gitignored (see CLAUDE.md).
- Never force-push, never skip hooks, never bypass the `founder-os`
  policy-engine safety layer when working in either repo.
- If a run finds nothing actionable in either repo, that's a valid,
  reportable outcome — do not manufacture a finding to justify a PR.
