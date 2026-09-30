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

current_user="$(id -un)"
current_group="$(id -gn)"
user_has_registered_group "$current_user" "$current_group" || fail "grupo primário do usuário atual não foi reconhecido"
pass "detecta grupo já cadastrado"

if ! session_user_has_group "$current_user" "$current_group"; then
  fail "grupo da sessão atual não foi reconhecido"
fi
pass "detecta grupo carregado na sessão atual"

if [[ "${AI_BASH_GEN_TEST_PRIVILEGED:-0}" == "1" ]]; then
  command -v sudo >/dev/null 2>&1 || fail "sudo ausente para teste privilegiado"
  sudo -n true || fail "sudo sem senha é necessário no teste privilegiado de CI"

  test_group="abgci$"
  cleanup_privileged() {
    sudo groupdel "$test_group" >/dev/null 2>&1 || true
  }
  trap 'cleanup_privileged; rm -rf "$tmp"' EXIT

  sudo groupadd "$test_group"
  SUDO=(sudo)

  if user_has_registered_group "$current_user" "$test_group"; then
    fail "grupo temporário já aparece antes do cadastro"
  fi

  authorize_client_user "$current_user" "$test_group"
  user_has_registered_group "$current_user" "$test_group" || fail "usermod -aG não efetivou o cadastro"
  [[ "${CLIENT_SESSION_REFRESH_REQUIRED:-}" == "yes" ]] || fail "sessão antiga não foi marcada para atualização"
  pass "detecta cadastro novo com sessão atual desatualizada"

  mkdir -p "$custom_runtime/routes"
  sudo chgrp "$test_group" "$custom_runtime" "$custom_runtime/routes"
  sudo chmod 0750 "$custom_runtime" "$custom_runtime/routes"
  : >"$custom_runtime/routes/generate.sock"
  sudo chgrp "$test_group" "$custom_runtime/routes/generate.sock"
  sudo chmod 0660 "$custom_runtime/routes/generate.sock"

  validate_client_route_access "$current_user" "$test_group" "$fake" "$custom_runtime"
  pass "nova sessão do usuário acessa rota após cadastro no grupo"

  cleanup_privileged
fi

echo "RESULTADO: APROVADO"
