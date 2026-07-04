#!/usr/bin/env bash
# scripts/install-hooks.sh — one-time setup per clone/environment.
# .git/hooks/ is never tracked by git, so the pre-commit secret scan has to be
# (re)installed explicitly here rather than just existing because it's in the repo.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cat > "$ROOT_DIR/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
exec "$(git rev-parse --show-toplevel)/scripts/check-secrets.sh"
EOF
chmod +x "$ROOT_DIR/.git/hooks/pre-commit"

echo "Installed pre-commit secret scan hook."
