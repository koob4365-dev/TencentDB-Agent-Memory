#!/usr/bin/env bash
# Shared environment bootstrap for TencentDB-Agent-Memory Cloud Agent dev setup.
# Source this file (`. .cursor/env.sh`) before running any module command so that
# a Node >= 22.16 toolchain is on PATH. The base image ships an older Node on
# PATH via /exec-daemon, so we explicitly select an nvm-managed Node 22.x and
# prepend it so it wins.

# Resolve repo root (directory that contains this .cursor/ folder).
if [ -n "${BASH_SOURCE:-}" ]; then
  _CURSOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  _CURSOR_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
export REPO_ROOT="$(cd "$_CURSOR_DIR/.." && pwd)"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  # Ensure a Node 22.x (>= 22.16, required by the modules' engines) is installed.
  if ! ls -d "$NVM_DIR"/versions/node/v22.*/bin >/dev/null 2>&1; then
    nvm install 22 >/dev/null 2>&1 || true
  fi
  # Select the highest installed nvm Node 22.x bin dir directly. We do NOT rely
  # on `nvm use`: the base image pre-injects an older Node 22.14 via /exec-daemon
  # which nvm treats as the active version and refuses to switch away from, so
  # `nvm use 22` is a no-op that leaves the old Node winning. Instead we resolve
  # the bin dir ourselves and prepend it unconditionally (stripping any existing
  # occurrence first) so the nvm-managed Node is always first on PATH.
  _NODE_BIN="$(ls -d "$NVM_DIR"/versions/node/v22.*/bin 2>/dev/null | sort -V | tail -1)"
  if [ -n "$_NODE_BIN" ]; then
    PATH="$(printf '%s' ":$PATH:" | sed -e "s#:$_NODE_BIN:#:#g" -e 's#^:##' -e 's#:$##')"
    export PATH="$_NODE_BIN:$PATH"
  fi
fi

# Pin pnpm to the version the repo expects (v10.x reads the modules' pnpm.*
# config that newer majors ignore). Avoid a bare `corepack enable`, which would
# resolve pnpm to "latest" and drift the version between runs.
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
if ! command -v pnpm >/dev/null 2>&1 || [ "$(pnpm -v 2>/dev/null | cut -d. -f1)" != "10" ]; then
  corepack prepare pnpm@10.33.3 --activate >/dev/null 2>&1 \
    || npm install -g pnpm@10.33.3 >/dev/null 2>&1 \
    || true
fi

# Local LLM credentials: real values should be provided via Cloud Agent secrets.
# Placeholders let the services boot and pass /health without a live key; actual
# memory extraction/injection needs valid keys.
export TDAI_LLM_API_KEY="${TDAI_LLM_API_KEY:-sk-local-dev-placeholder}"
export TDAI_LLM_BASE_URL="${TDAI_LLM_BASE_URL:-https://api.openai.com/v1}"
export TDAI_LLM_MODEL="${TDAI_LLM_MODEL:-gpt-4o-mini}"
