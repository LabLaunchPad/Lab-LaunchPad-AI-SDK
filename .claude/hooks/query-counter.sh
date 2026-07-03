#!/usr/bin/env bash
# .claude/hooks/query-counter.sh
#
# UserPromptSubmit hook. Increments a cumulative, persisted, local counter
# of user prompts. Every 7th prompt, injects additionalContext instructing
# Claude to run the improvement-review process (see
# .claude/skills/improvement-review/SKILL.md).
#
# NOTE (documented limitation): this counter lives in a gitignored local
# file (.claude/state/query-count.txt). It survives across turns/sessions
# within the same container, but resets to 0 if the container is fully
# reclaimed. We deliberately do NOT auto-commit it on every message (that
# would spam the commit history) — see CLAUDE.md for the tradeoff.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/../state"
COUNTER_FILE="$STATE_DIR/query-count.txt"
THRESHOLD=7

mkdir -p "$STATE_DIR"

# Consume stdin (the hook payload); we don't need any field from it.
cat >/dev/null

count=0
if [[ -f "$COUNTER_FILE" ]]; then
  raw="$(cat "$COUNTER_FILE" 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    count="$raw"
  fi
fi

count=$((count + 1))
echo "$count" > "$COUNTER_FILE"

if (( count % THRESHOLD == 0 )); then
  context="Prompt #$count since the query counter was last reset. Per this project's convention, run the improvement-review process now: follow .claude/skills/improvement-review/SKILL.md. Gather real evidence (run existing tests/lints/benchmarks in this repo and, if available, in rahlplx/solo-founder-wingman), identify concrete evidence-backed improvement candidates, rank alternatives with tradeoffs, and — for each repo where there is something real to propose — open a PR with a dated report. Never auto-merge."
  node -e '
    const ctx = process.argv[1];
    process.stdout.write(JSON.stringify({
      continue: true,
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: ctx
      }
    }));
  ' "$context"
else
  echo '{"continue": true}'
fi

exit 0
