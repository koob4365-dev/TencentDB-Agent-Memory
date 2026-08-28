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
  # Ensure a Node 22.x (>= 22.16, required by the modules' engines) is available.
  if ! nvm use 22 >/dev/null 2>&1; then
    nvm install 22 >/dev/null 2>&1 || true
    nvm use 22 >/dev/null 2>&1 || true
  fi
  # Prepend the selected Node's bin dir so it beats any older Node earlier on PATH.
  _NODE_BIN="$(dirname "$(nvm which current 2>/dev/null || command -v node)")"
  case ":$PATH:" in
    *":$_NODE_BIN:"*) : ;;
    *) export PATH="$_NODE_BIN:$PATH" ;;
  esac
fi

# Enable corepack so pnpm resolves consistently.
corepack enable >/dev/null 2>&1 || true

# Local LLM credentials: real values should be provided via Cloud Agent secrets.
# Placeholders let the services boot and pass /health without a live key; actual
# memory extraction/injection needs valid keys.
export TDAI_LLM_API_KEY="${TDAI_LLM_API_KEY:-sk-local-dev-placeholder}"
export TDAI_LLM_BASE_URL="${TDAI_LLM_BASE_URL:-https://api.openai.com/v1}"
export TDAI_LLM_MODEL="${TDAI_LLM_MODEL:-gpt-4o-mini}"
