#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TEST_BIN="$ROOT/ai-bash-gen-generation-test"
[[ -x "$TEST_BIN" ]] || {
  echo "[ERRO] binário de teste não encontrado ou não executável: $TEST_BIN" >&2
  exit 2
}
exec "$TEST_BIN" "$@"
