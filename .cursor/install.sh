#!/usr/bin/env bash
# Idempotent dependency + local-config bootstrap for TencentDB-Agent-Memory.
# Run after checkout by the Cloud Agent `install` phase. Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/env.sh"

cd "$REPO_ROOT"

echo "==> Node: $(node -v)  npm: $(npm -v)  pnpm: $(pnpm -v)"

# ── MemoryCore (npm; --legacy-peer-deps avoids an npm arborist crash triggered
#    by the optional openclaw/node-llama-cpp peer deps, and skips their broken
#    transitive workspace refs while keeping devDependencies for build/test). ──
echo "==> Installing MemoryCore deps"
( cd MemoryCore && npm install --legacy-peer-deps --no-audit --no-fund )

# ── MemoryKnowledge (pnpm, standalone — not part of any workspace). ──
echo "==> Installing MemoryKnowledge deps"
( cd MemoryKnowledge && pnpm install --ignore-workspace )
[ -f MemoryKnowledge/.env ] || cp MemoryKnowledge/.env.example MemoryKnowledge/.env

# ── MemoryProxy (npm; deterministic install from the committed lockfile). ──
echo "==> Installing MemoryProxy deps"
( cd MemoryProxy && npm ci --no-audit --no-fund )
# Generate a local dev config (config.yaml is gitignored). The shipped example
# assumes Redis; for single-node local dev we disable Redis and use the SQLite
# storage backend instead.
if [ ! -f MemoryProxy/config.yaml ]; then
  cat > MemoryProxy/config.yaml <<'YAML'
server:
  host: 127.0.0.1
  port: 8096
upstream:
  url: https://api.openai.com/v1
  apiKey: "sk-local-dev-placeholder"
  agents: {}
log:
  backend: console
  level: info
redis:
  enabled: false
storage:
  enabled: true
  backend: sqlite
auth:
  enabled: false
  url: "http://127.0.0.1:8420"
systemUsers: []
injection:
  enabled: true
  injectors: ["skill", "tdai-memory"]
tdai:
  enabled: true
  endpoint: "http://127.0.0.1:8420"
  apiKey: "local"
  serviceId: "default"
skill:
  endpoint: "http://127.0.0.1:8420"
  serviceToken: "local"
  serviceId: "context-proxy"
YAML
fi

# ── MemoryPanel backend (pnpm) + web frontend (npm). ──
echo "==> Installing MemoryPanel backend deps"
( cd MemoryPanel && pnpm install )
[ -f MemoryPanel/.env ] || cp MemoryPanel/.env.example MemoryPanel/.env
if [ ! -f MemoryPanel/config/metadata-instances.json ]; then
  cp MemoryPanel/config/metadata-instances.example.json MemoryPanel/config/metadata-instances.json
  # Kernel gateway auth is disabled for local dev; any bearer value works.
  sed -i 's/REPLACE_WITH_KERNEL_BEARER_TOKEN/local/g' MemoryPanel/config/metadata-instances.json
fi

echo "==> Installing MemoryPanel web deps"
( cd MemoryPanel/web && npm ci --no-audit --no-fund )

echo "==> Install complete."
