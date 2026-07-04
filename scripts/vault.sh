#!/usr/bin/env bash
# scripts/vault.sh — lightweight local secret store for this project.
#
# Secrets live in .claude/secrets/.env (gitignored, chmod 600 file / 700 dir),
# never committed, never printed back by this script. This is NOT a real
# secrets manager (no encryption at rest) — it's a convenience layer so a key
# only has to be entered once per environment instead of re-pasted every
# session. For anything beyond solo-founder scale, migrate to a real vault
# (e.g. a cloud secret manager) before it matters.
#
# Usage:
#   ./scripts/vault.sh set NAME        # reads the value from stdin, e.g.:
#                                       #   echo -n "the-key" | ./scripts/vault.sh set GEMINI_API_KEY
#   ./scripts/vault.sh get NAME        # prints the value (only when you ask by name)
#   ./scripts/vault.sh list            # prints stored NAMES only, never values
#   ./scripts/vault.sh load            # prints `export NAME=value` lines for `source`-ing

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_DIR="$ROOT_DIR/.claude/secrets"
VAULT_FILE="$VAULT_DIR/.env"

mkdir -p "$VAULT_DIR"
touch "$VAULT_FILE"
chmod 700 "$VAULT_DIR"
chmod 600 "$VAULT_FILE"

cmd="${1:-}"

case "$cmd" in
  set)
    name="${2:?usage: vault.sh set NAME   (value is read from stdin)}"
    value="$(cat)"
    if [[ -z "$value" ]]; then
      echo "Refusing to store an empty value for $name" >&2
      exit 1
    fi
    tmp_file="$(mktemp "$VAULT_DIR/.env.XXXXXX")"
    grep -v "^${name}=" "$VAULT_FILE" > "$tmp_file" 2>/dev/null || true
    mv "$tmp_file" "$VAULT_FILE"
    echo "${name}=${value}" >> "$VAULT_FILE"
    chmod 600 "$VAULT_FILE"
    echo "Stored ${name} (${#value} chars). Value not echoed."
    ;;
  get)
    name="${2:?usage: vault.sh get NAME}"
    grep "^${name}=" "$VAULT_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true
    ;;
  list)
    cut -d= -f1 "$VAULT_FILE" 2>/dev/null || true
    ;;
  load)
    while IFS='=' read -r k v; do
      [[ -z "$k" ]] && continue
      printf 'export %s=%q\n' "$k" "$v"
    done < "$VAULT_FILE"
    ;;
  *)
    echo "Usage: vault.sh {set NAME|get NAME|list|load}" >&2
    exit 1
    ;;
esac
