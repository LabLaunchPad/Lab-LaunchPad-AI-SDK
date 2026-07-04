#!/usr/bin/env bash
# scripts/gemini-query.sh — token-efficient direct Gemini API wrapper.
#
# Deliberately bypasses `gemini` CLI's headless mode: that loads a full
# coding-agent harness (workspace context, tool schemas, thinking mode) even
# for a trivial query — measured at 9000+ tokens for a one-word reply. This
# hits the Gemini API's generateContent endpoint directly instead: ~8 tokens
# for the same kind of call.
#
# Role in this project: second-opinion/validation on findings *we* already
# gathered (via WebSearch/Explore), not live web search itself — the
# `google_search` grounding tool returned 429 RESOURCE_EXHAUSTED on this key's
# tier during setup (plain generation works fine; grounding quota is
# separate and was already exhausted). Enable billing on the Google AI
# Studio project if live Gemini-side search is actually needed later.
#
# Usage:
#   ./scripts/gemini-query.sh [-m MODEL] "prompt text"
#   echo "prompt text" | ./scripts/gemini-query.sh [-m MODEL]
#
# Falls back across GEMINI_API_KEY, GEMINI_API_KEY_2, GEMINI_API_KEY_3 (as
# stored in the vault) on rate-limit/auth errors, with exponential backoff
# per key. Logs every call (key index, not value; model; status; tokens) to
# .claude/state/gemini-query.log (gitignored).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_FILE="$ROOT_DIR/.claude/secrets/.env"
LOG_DIR="$ROOT_DIR/.claude/state"
LOG_FILE="$LOG_DIR/gemini-query.log"
mkdir -p "$LOG_DIR"

MODEL="gemini-3.1-flash-lite"
while getopts "m:" opt; do
  case "$opt" in
    m) MODEL="$OPTARG" ;;
    *) echo "Usage: $0 [-m MODEL] \"prompt\"" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -ge 1 ]]; then
  PROMPT="$1"
else
  PROMPT="$(cat)"
fi

if [[ -z "$PROMPT" ]]; then
  echo "No prompt given (arg or stdin)." >&2
  exit 1
fi

if [[ ! -f "$VAULT_FILE" ]]; then
  echo "No vault file at $VAULT_FILE — run scripts/vault.sh set GEMINI_API_KEY first." >&2
  exit 1
fi

KEYS=()
for name in GEMINI_API_KEY GEMINI_API_KEY_2 GEMINI_API_KEY_3; do
  val="$(grep "^${name}=" "$VAULT_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true)"
  [[ -n "$val" ]] && KEYS+=("$val")
done

if [[ "${#KEYS[@]}" -eq 0 ]]; then
  echo "No Gemini API keys found in vault." >&2
  exit 1
fi

log() {
  printf '%s key=%s model=%s status=%s tokens=%s outcome=%s\n' \
    "$(date -u +%FT%TZ)" "$1" "$2" "$3" "$4" "$5" >> "$LOG_FILE"
}

json_escape() {
  node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1"
}

PROMPT_JSON="$(json_escape "$PROMPT")"
BODY=$(printf '{"contents":[{"parts":[{"text":%s}]}]}' "$PROMPT_JSON")

key_index=0
for key in "${KEYS[@]}"; do
  key_index=$((key_index + 1))
  attempt=0
  max_attempts=3
  while [[ "$attempt" -lt "$max_attempts" ]]; do
    attempt=$((attempt + 1))
    resp="$(curl -s -w "\n%{http_code}" -X POST \
      "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${key}" \
      -H "Content-Type: application/json" -d "$BODY")"
    status="$(echo "$resp" | tail -1)"
    body="$(echo "$resp" | sed '$d')"

    if [[ "$status" == "200" ]]; then
      tokens="$(echo "$body" | node -e '
        let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{
          try { console.log(JSON.parse(d).usageMetadata?.totalTokenCount ?? "?"); }
          catch { console.log("?"); }
        });')"
      log "$key_index" "$MODEL" "$status" "$tokens" "success"
      echo "$body" | node -e '
        let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{
          const j = JSON.parse(d);
          process.stdout.write((j.candidates?.[0]?.content?.parts||[]).map(p=>p.text||"").join(""));
        });'
      echo
      exit 0
    fi

    if [[ "$status" == "429" || "$status" =~ ^5 ]]; then
      log "$key_index" "$MODEL" "$status" "-" "retrying (attempt $attempt)"
      sleep $((2 ** attempt))
      continue
    fi

    # Auth/invalid-key errors (401/403/400) or anything else: don't retry
    # this key, move straight to the next one.
    log "$key_index" "$MODEL" "$status" "-" "failed, trying next key"
    break
  done
done

echo "All available Gemini keys exhausted or failing. Last response:" >&2
echo "$body" >&2
log "all" "$MODEL" "exhausted" "-" "failure"
exit 2
