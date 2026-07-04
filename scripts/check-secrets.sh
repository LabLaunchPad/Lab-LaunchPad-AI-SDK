#!/usr/bin/env bash
# scripts/check-secrets.sh — lightweight regex secret scanner for staged changes.
# Not a replacement for a real scanner (e.g. gitleaks/semgrep) at team scale,
# but catches the common accidental-paste cases with zero extra dependencies.

set -euo pipefail

PATTERNS=(
  'AIza[0-9A-Za-z_-]{20,}'          # Google/Gemini API key
  'sk-[A-Za-z0-9]{20,}'             # OpenAI-style secret key
  'sk_live_[A-Za-z0-9]{16,}'        # Stripe live secret key
  'AKIA[0-9A-Z]{16}'                # AWS access key ID
  'BEGIN [A-Z ]*PRIVATE KEY'
)

staged_files="$(git diff --cached --name-only --diff-filter=ACM)"
[[ -z "$staged_files" ]] && exit 0

found=0
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  # Never scan the vault or its gitignored contents; they can't be staged anyway,
  # but skip explicitly for clarity and speed.
  [[ "$file" == .claude/secrets/* ]] && continue
  for pattern in "${PATTERNS[@]}"; do
    if git diff --cached -- "$file" | grep -E -q -- "$pattern"; then
      echo "Possible secret matching /$pattern/ in staged file: $file" >&2
      found=1
    fi
  done
done <<< "$staged_files"

if [[ "$found" -eq 1 ]]; then
  echo "" >&2
  echo "Pre-commit secret scan blocked this commit. Remove the secret, or store it" >&2
  echo "via ./scripts/vault.sh instead (see .env.example / docs)." >&2
  exit 1
fi

exit 0
