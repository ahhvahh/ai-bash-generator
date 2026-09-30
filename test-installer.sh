#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export AI_BASH_GEN_INSTALLER_LIB_ONLY=1
# shellcheck disable=SC1091
source "$ROOT/install-binary.sh"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

validate_absolute_path "teste" "/usr/local/bin/ai-bash-gen" || fail "caminho absoluto válido foi recusado"
pass "aceita caminho absoluto"

if validate_absolute_path "teste" "s" >/dev/null 2>&1; then
  fail "valor relativo s foi aceito como destino"
fi
pass "recusa destino relativo s"

if validate_absolute_path "teste" "./ai-bash-gen" >/dev/null 2>&1; then
  fail "caminho relativo foi aceito"
fi
pass "recusa caminhos relativos"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fake="$tmp/fake-ai-bash-gen"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--show-paths" ]]; then
  runtime="${AI_BASH_GEN_RUNTIME_DIR:-/run/ai-bash-gen}"
  echo "runtime_dir=$runtime"
  echo "routes_dir=$runtime/routes"
  echo "llama_socket=$runtime/internal/llama.sock"
  echo "generate_socket=$runtime/routes/generate.sock"
fi
EOF
chmod +x "$fake"

custom_runtime="$tmp/custom-runtime"
mapfile -t routes < <(discover_route_sockets "$fake" "$custom_runtime")
[[ ${#routes[@]} -eq 1 ]] || fail "esperava 1 rota pública, recebeu ${#routes[@]}"
[[ "${routes[0]}" == "generate_socket|$custom_runtime/routes/generate.sock" ]] || fail "rota inesperada: ${routes[0]}"
pass "runtime personalizado é propagado para --show-paths"

grep -Fq 'Environment=AI_BASH_GEN_RUNTIME_DIR=$runtime_dir' "$ROOT/install-binary.sh" || fail "unit não propaga AI_BASH_GEN_RUNTIME_DIR"
pass "unit systemd propaga runtime configurado"

echo "RESULTADO: APROVADO"
