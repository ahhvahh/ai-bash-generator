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

FORCE_MODE=1
[[ "$(ask_value 'teste force' 'valor-padrao')" == "valor-padrao" ]] || fail "--force não aplicou valor padrão"
ask_yes_no "teste force yes" "Y" || fail "--force deveria aceitar resposta padrão Y"
if ask_yes_no "teste force no" "N"; then
  fail "--force deveria preservar resposta padrão N"
fi
confirm_value "teste force" "ok"
FORCE_MODE=0
pass "--force aplica padrões sem leitura interativa"

model_catalog_resolve "$DEFAULT_MODEL_KEY" || fail "modelo padrão não existe no catálogo"
[[ "$MODEL_KEY" == "qwen35-08b-q4" ]] || fail "modelo padrão inesperado: $MODEL_KEY"
[[ "$MODEL_SHA256" == "57d1997790d1744fba5b40a7317df71ea5e2acee28c47e78f0cce39c0703f8cf" ]] || fail "SHA do modelo padrão inesperado"
[[ "$MODEL_URL" == https://huggingface.co/ggml-org/Qwen3.5-0.8B-GGUF/* ]] || fail "modelo padrão não usa repositório ggml-org esperado"
pass "catálogo define Qwen3.5-0.8B Q4_0 como padrão"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_llama="$tmp/llama-server"
cat >"$fake_llama" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--help" ]]; then
  echo '  --host HOST bind to UNIX socket when HOST ends with .sock'
  exit 0
fi
exit 0
EOF
chmod +x "$fake_llama"
validate_llama_source "$fake_llama" || fail "llama-server compatível foi recusado"
pass "detecta llama-server compatível com Unix Socket"

AI_BASH_GEN_LLAMA_SERVER="$fake_llama"
export AI_BASH_GEN_LLAMA_SERVER
detected_llama="$(detect_llama_default)"
[[ "$detected_llama" == "$fake_llama" ]] || fail "override AI_BASH_GEN_LLAMA_SERVER não foi priorizado"

LLAMA_SOURCE=""
LLAMA_INSTALLATION_MODE=""
ensure_llama_server_available
[[ "$LLAMA_SOURCE" == "$fake_llama" ]] || fail "preflight não preservou llama-server existente"
[[ "$LLAMA_INSTALLATION_MODE" == "existing" ]] || fail "modo do llama-server deveria ser existing"
unset AI_BASH_GEN_LLAMA_SERVER
pass "preflight reutiliza llama-server compatível sem reinstalar"

[[ "$LLAMA_CPP_VERSION" == "v0.5.0" ]] || fail "versão do llama.cpp não está fixada em v0.5.0"
[[ "$LLAMA_CPP_COMMIT" == "7fe450e19305b828c199d602c23a8337aaa1f03b" ]] || fail "commit do llama.cpp não corresponde à versão fixada"
grep -Fq -- '--target llama-server' "$ROOT/install-binary.sh" || fail "instalador não compila especificamente o target llama-server"
grep -Fq -- '-DBUILD_SHARED_LIBS=OFF' "$ROOT/install-binary.sh" || fail "build do llama.cpp não está configurado como estático"
pass "instalação automática do llama.cpp está fixada e limitada ao llama-server"

fake_llama_repo="$tmp/fake-llama-repo"
mkdir -p "$fake_llama_repo"
cat >"$fake_llama_repo/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(fake_llama NONE)
set(OUT "${CMAKE_BINARY_DIR}/bin/llama-server")
add_custom_command(
  OUTPUT "${OUT}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_BINARY_DIR}/bin"
  COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_SOURCE_DIR}/llama-server.sh" "${OUT}"
  COMMAND /bin/chmod +x "${OUT}"
  DEPENDS "${CMAKE_SOURCE_DIR}/llama-server.sh"
)
add_custom_target(llama-server DEPENDS "${OUT}")
EOF
cat >"$fake_llama_repo/llama-server.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--help" ]]; then
  echo '  --host HOST bind to UNIX socket when HOST ends with .sock'
  exit 0
fi
exit 0
EOF
git -C "$fake_llama_repo" init -q
git -C "$fake_llama_repo" config user.name "CI"
git -C "$fake_llama_repo" config user.email "ci@example.invalid"
git -C "$fake_llama_repo" add CMakeLists.txt llama-server.sh
git -C "$fake_llama_repo" commit -q -m "fake llama"
git -C "$fake_llama_repo" tag v-test

saved_llama_repo="$LLAMA_CPP_REPOSITORY"
saved_llama_version="$LLAMA_CPP_VERSION"
saved_llama_commit="$LLAMA_CPP_COMMIT"
saved_build_packages=("${LLAMA_CPP_BUILD_PACKAGES[@]}")
LLAMA_CPP_REPOSITORY="$fake_llama_repo"
LLAMA_CPP_VERSION="v-test"
LLAMA_CPP_COMMIT="$(git -C "$fake_llama_repo" rev-parse HEAD)"
LLAMA_CPP_BUILD_PACKAGES=()
SUDO=()

fake_installed_llama="$tmp/installed/llama-server"
if [[ "${AI_BASH_GEN_TEST_PRIVILEGED:-0}" == "1" ]]; then
  command -v sudo >/dev/null 2>&1 || fail "sudo ausente para exercitar instalação automática"
  sudo -n true || fail "sudo sem senha é necessário para exercitar instalação automática"
  SUDO=(sudo)
  install_llama_cpp_from_source "$fake_installed_llama"
  validate_llama_source "$fake_installed_llama" || fail "instalação automática não produziu llama-server válido"
  pass "fluxo de instalação automática compila e instala o target llama-server"
  sudo rm -rf -- "$tmp/installed"
else
  pass "fluxo de instalação automática será exercitado no teste privilegiado"
fi
SUDO=()

LLAMA_CPP_REPOSITORY="$saved_llama_repo"
LLAMA_CPP_VERSION="$saved_llama_version"
LLAMA_CPP_COMMIT="$saved_llama_commit"
LLAMA_CPP_BUILD_PACKAGES=("${saved_build_packages[@]}")

fake_model="$tmp/model.gguf"
printf 'GGUF-test\n' >"$fake_model"
validate_model_source "$fake_model" || fail "modelo GGUF válido foi recusado"
pass "detecta modelo GGUF válido"

saved_model_packages=("${MODEL_DOWNLOAD_PACKAGES[@]}")
saved_path="$PATH"
fake_bin="$tmp/fake-bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      output="$2"
      shift 2
      ;;
    --fail|--location)
      shift
      ;;
    --retry|--retry-delay|--continue-at)
      shift 2
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done
[[ -n "$output" && "$url" == file://* ]] || exit 2
cp -- "${url#file://}" "$output"
EOF
chmod +x "$fake_bin/curl"
PATH="$fake_bin:$PATH"

MODEL_DOWNLOAD_PACKAGES=()
MODEL_KEY="fake-model"
MODEL_LABEL="Fake GGUF"
MODEL_FILE="fake.gguf"
MODEL_SIZE="9 bytes"
MODEL_URL="file://$fake_model"
MODEL_SHA256="$(sha256sum "$fake_model" | awk '{print $1}')"
SUDO=()
fake_state="$tmp/model-state"
download_selected_model "$fake_state"
[[ "$MODEL_SOURCE" == "$fake_state/models/model.gguf" ]] || fail "download não usou caminho estável model.gguf"
cmp -s "$fake_model" "$MODEL_SOURCE" || fail "modelo baixado não corresponde à origem"
[[ -f "$fake_state/models/model.info" ]] || fail "metadata model.info não foi criada"
MODEL_DOWNLOAD_PACKAGES=("${saved_model_packages[@]}")
PATH="$saved_path"
pass "download de modelo verifica e instala arquivo GGUF em caminho estável sem exigir curl no host de build"

if validate_model_source "$tmp/model.bin" >/dev/null 2>&1; then
  fail "modelo sem extensão GGUF foi aceito"
fi
pass "recusa modelo sem extensão GGUF"

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

grep -Fq 'Environment=AI_BASH_GEN_LOG_LEVEL=debug' "$ROOT/install-binary.sh" || fail "unit não habilita logs debug do ai-bash-gen"
grep -Fq 'Environment=AI_BASH_GEN_LLAMA_LOG_VERBOSITY=5' "$ROOT/install-binary.sh" || fail "unit não habilita logs debug do llama-server"
grep -Fq 'StandardOutput=journal' "$ROOT/install-binary.sh" || fail "unit não envia stdout ao journal"
grep -Fq 'StandardError=journal' "$ROOT/install-binary.sh" || fail "unit não envia stderr ao journal"
pass "unit systemd mantém debug completo no journald"

[[ "$DEFAULT_CONTEXT_SIZE" == "32768" ]] || fail "contexto padrão inesperado: $DEFAULT_CONTEXT_SIZE"
[[ "$DEFAULT_REQUEST_TIMEOUT" == "10m" ]] || fail "request timeout padrão inesperado: $DEFAULT_REQUEST_TIMEOUT"
[[ "$DEFAULT_MAX_TOKENS" == "4096" ]] || fail "max_tokens padrão inesperado: $DEFAULT_MAX_TOKENS"
pass "perfil padrão usa contexto 32k e saída 4k"

managed_config="$tmp/managed-config.yaml"
cat >"$managed_config" <<'EOF'
# ai-bash-gen - configuração bootstrap
llama:
  binary: "/usr/local/lib/ai-bash-gen/llama-server"
  model: "/var/lib/ai-bash-gen/models/model.gguf"
  context_size: 2048
  startup_timeout: 2m
  request_timeout: 3m
  max_tokens: 1536
  temperature: 0.2
EOF
FORCE_MODE=1
SUDO=()
migrate_managed_runtime_defaults "$managed_config"
FORCE_MODE=0
grep -Eq '^[[:space:]]*context_size:[[:space:]]*32768
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

  test_group="abgci$(date +%s)"
  cleanup_privileged() {
    sudo groupdel "$test_group" >/dev/null 2>&1 || true
  }
  trap 'cleanup_privileged; rm -rf "$tmp"' EXIT

  sudo groupadd "$test_group"
  SUDO=(sudo)

  force_source="$tmp/force-source"
  force_install_dir="$tmp/force-install"
  force_target="$force_install_dir/ai-bash-gen"
  mkdir -p "$force_install_dir"
  printf 'versao-antiga\n' | sudo tee "$force_target" >/dev/null
  printf 'versao-nova\n' >"$force_source"
  sudo chmod 0755 "$force_target"
  chmod 0755 "$force_source"
  FORCE_MODE=1
  install_binary "$force_source" "$force_target"
  FORCE_MODE=0
  [[ "$(cat "$force_target")" == "versao-nova" ]] || fail "--force não substituiu binário existente"
  compgen -G "$force_target.backup.*" >/dev/null || fail "--force não criou backup do binário substituído"
  sudo rm -rf -- "$force_install_dir"
  pass "--force substitui binário diferente sem cancelar a instalação"

  service_group="abgsg$(date +%s)"
  service_user="abgsu$(date +%s)"
  sudo groupadd "$service_group"
  sudo useradd --system --gid "$service_group" --home-dir "$tmp/service-home" --no-create-home --shell /usr/sbin/nologin "$service_user"
  service_uid_before="$(id -u "$service_user")"
  service_gid_before="$(getent group "$service_group" | cut -d: -f3)"
  create_service_account "$service_user" "$service_group" "$tmp/service-home"
  [[ "$(id -u "$service_user")" == "$service_uid_before" ]] || fail "usuário existente foi recriado/alterado"
  [[ "$(getent group "$service_group" | cut -d: -f3)" == "$service_gid_before" ]] || fail "grupo existente foi recriado/alterado"
  sudo userdel "$service_user"
  sudo groupdel "$service_group"
  pass "conta e grupo de serviço existentes são reutilizados sem recriação"

  fake_dep_bin="$tmp/fake-dependency-check"
  fake_dep_config="$tmp/fake-config.yaml"
  cat >"$fake_dep_bin" <<'EOF'
#!/usr/bin/env bash
printf 'dependências: OK\n'
exit 0
EOF
  chmod +x "$fake_dep_bin"
  : >"$fake_dep_config"

  saved_path="$PATH"
  PATH="/usr/bin:/bin"
  validate_runtime_dependencies "$fake_dep_bin" "$fake_dep_config" "$current_user" "yes"
  PATH="$saved_path"
  pass "validação runtime resolve runuser mesmo fora do PATH do usuário"

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
 "$managed_config" || fail "context_size antigo não foi migrado"
grep -Eq '^[[:space:]]*request_timeout:[[:space:]]*10m
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

  test_group="abgci$(date +%s)"
  cleanup_privileged() {
    sudo groupdel "$test_group" >/dev/null 2>&1 || true
  }
  trap 'cleanup_privileged; rm -rf "$tmp"' EXIT

  sudo groupadd "$test_group"
  SUDO=(sudo)

  force_source="$tmp/force-source"
  force_install_dir="$tmp/force-install"
  force_target="$force_install_dir/ai-bash-gen"
  mkdir -p "$force_install_dir"
  printf 'versao-antiga\n' | sudo tee "$force_target" >/dev/null
  printf 'versao-nova\n' >"$force_source"
  sudo chmod 0755 "$force_target"
  chmod 0755 "$force_source"
  FORCE_MODE=1
  install_binary "$force_source" "$force_target"
  FORCE_MODE=0
  [[ "$(cat "$force_target")" == "versao-nova" ]] || fail "--force não substituiu binário existente"
  compgen -G "$force_target.backup.*" >/dev/null || fail "--force não criou backup do binário substituído"
  sudo rm -rf -- "$force_install_dir"
  pass "--force substitui binário diferente sem cancelar a instalação"

  service_group="abgsg$(date +%s)"
  service_user="abgsu$(date +%s)"
  sudo groupadd "$service_group"
  sudo useradd --system --gid "$service_group" --home-dir "$tmp/service-home" --no-create-home --shell /usr/sbin/nologin "$service_user"
  service_uid_before="$(id -u "$service_user")"
  service_gid_before="$(getent group "$service_group" | cut -d: -f3)"
  create_service_account "$service_user" "$service_group" "$tmp/service-home"
  [[ "$(id -u "$service_user")" == "$service_uid_before" ]] || fail "usuário existente foi recriado/alterado"
  [[ "$(getent group "$service_group" | cut -d: -f3)" == "$service_gid_before" ]] || fail "grupo existente foi recriado/alterado"
  sudo userdel "$service_user"
  sudo groupdel "$service_group"
  pass "conta e grupo de serviço existentes são reutilizados sem recriação"

  fake_dep_bin="$tmp/fake-dependency-check"
  fake_dep_config="$tmp/fake-config.yaml"
  cat >"$fake_dep_bin" <<'EOF'
#!/usr/bin/env bash
printf 'dependências: OK\n'
exit 0
EOF
  chmod +x "$fake_dep_bin"
  : >"$fake_dep_config"

  saved_path="$PATH"
  PATH="/usr/bin:/bin"
  validate_runtime_dependencies "$fake_dep_bin" "$fake_dep_config" "$current_user" "yes"
  PATH="$saved_path"
  pass "validação runtime resolve runuser mesmo fora do PATH do usuário"

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
 "$managed_config" || fail "request_timeout antigo não foi migrado"
grep -Eq '^[[:space:]]*max_tokens:[[:space:]]*4096
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

  test_group="abgci$(date +%s)"
  cleanup_privileged() {
    sudo groupdel "$test_group" >/dev/null 2>&1 || true
  }
  trap 'cleanup_privileged; rm -rf "$tmp"' EXIT

  sudo groupadd "$test_group"
  SUDO=(sudo)

  force_source="$tmp/force-source"
  force_install_dir="$tmp/force-install"
  force_target="$force_install_dir/ai-bash-gen"
  mkdir -p "$force_install_dir"
  printf 'versao-antiga\n' | sudo tee "$force_target" >/dev/null
  printf 'versao-nova\n' >"$force_source"
  sudo chmod 0755 "$force_target"
  chmod 0755 "$force_source"
  FORCE_MODE=1
  install_binary "$force_source" "$force_target"
  FORCE_MODE=0
  [[ "$(cat "$force_target")" == "versao-nova" ]] || fail "--force não substituiu binário existente"
  compgen -G "$force_target.backup.*" >/dev/null || fail "--force não criou backup do binário substituído"
  sudo rm -rf -- "$force_install_dir"
  pass "--force substitui binário diferente sem cancelar a instalação"

  service_group="abgsg$(date +%s)"
  service_user="abgsu$(date +%s)"
  sudo groupadd "$service_group"
  sudo useradd --system --gid "$service_group" --home-dir "$tmp/service-home" --no-create-home --shell /usr/sbin/nologin "$service_user"
  service_uid_before="$(id -u "$service_user")"
  service_gid_before="$(getent group "$service_group" | cut -d: -f3)"
  create_service_account "$service_user" "$service_group" "$tmp/service-home"
  [[ "$(id -u "$service_user")" == "$service_uid_before" ]] || fail "usuário existente foi recriado/alterado"
  [[ "$(getent group "$service_group" | cut -d: -f3)" == "$service_gid_before" ]] || fail "grupo existente foi recriado/alterado"
  sudo userdel "$service_user"
  sudo groupdel "$service_group"
  pass "conta e grupo de serviço existentes são reutilizados sem recriação"

  fake_dep_bin="$tmp/fake-dependency-check"
  fake_dep_config="$tmp/fake-config.yaml"
  cat >"$fake_dep_bin" <<'EOF'
#!/usr/bin/env bash
printf 'dependências: OK\n'
exit 0
EOF
  chmod +x "$fake_dep_bin"
  : >"$fake_dep_config"

  saved_path="$PATH"
  PATH="/usr/bin:/bin"
  validate_runtime_dependencies "$fake_dep_bin" "$fake_dep_config" "$current_user" "yes"
  PATH="$saved_path"
  pass "validação runtime resolve runuser mesmo fora do PATH do usuário"

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
 "$managed_config" || fail "max_tokens antigo não foi migrado"
compgen -G "$managed_config.backup.*" >/dev/null || fail "migração não criou backup da configuração"
pass "configuração bootstrap antiga é migrada para os novos padrões"

custom_config="$tmp/custom-config.yaml"
cat >"$custom_config" <<'EOF'
llama:
  binary: "/usr/local/lib/ai-bash-gen/llama-server"
  model: "/var/lib/ai-bash-gen/models/model.gguf"
  context_size: 8192
  startup_timeout: 2m
  request_timeout: 5m
  max_tokens: 2048
  temperature: 0.1
EOF
custom_before="$(sha256sum "$custom_config" | awk '{print $1}')"
FORCE_MODE=1
migrate_managed_runtime_defaults "$custom_config"
FORCE_MODE=0
custom_after="$(sha256sum "$custom_config" | awk '{print $1}')"
[[ "$custom_before" == "$custom_after" ]] || fail "configuração personalizada foi alterada"
pass "configuração personalizada permanece intacta"

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

  test_group="abgci$(date +%s)"
  cleanup_privileged() {
    sudo groupdel "$test_group" >/dev/null 2>&1 || true
  }
  trap 'cleanup_privileged; rm -rf "$tmp"' EXIT

  sudo groupadd "$test_group"
  SUDO=(sudo)

  force_source="$tmp/force-source"
  force_install_dir="$tmp/force-install"
  force_target="$force_install_dir/ai-bash-gen"
  mkdir -p "$force_install_dir"
  printf 'versao-antiga\n' | sudo tee "$force_target" >/dev/null
  printf 'versao-nova\n' >"$force_source"
  sudo chmod 0755 "$force_target"
  chmod 0755 "$force_source"
  FORCE_MODE=1
  install_binary "$force_source" "$force_target"
  FORCE_MODE=0
  [[ "$(cat "$force_target")" == "versao-nova" ]] || fail "--force não substituiu binário existente"
  compgen -G "$force_target.backup.*" >/dev/null || fail "--force não criou backup do binário substituído"
  sudo rm -rf -- "$force_install_dir"
  pass "--force substitui binário diferente sem cancelar a instalação"

  service_group="abgsg$(date +%s)"
  service_user="abgsu$(date +%s)"
  sudo groupadd "$service_group"
  sudo useradd --system --gid "$service_group" --home-dir "$tmp/service-home" --no-create-home --shell /usr/sbin/nologin "$service_user"
  service_uid_before="$(id -u "$service_user")"
  service_gid_before="$(getent group "$service_group" | cut -d: -f3)"
  create_service_account "$service_user" "$service_group" "$tmp/service-home"
  [[ "$(id -u "$service_user")" == "$service_uid_before" ]] || fail "usuário existente foi recriado/alterado"
  [[ "$(getent group "$service_group" | cut -d: -f3)" == "$service_gid_before" ]] || fail "grupo existente foi recriado/alterado"
  sudo userdel "$service_user"
  sudo groupdel "$service_group"
  pass "conta e grupo de serviço existentes são reutilizados sem recriação"

  fake_dep_bin="$tmp/fake-dependency-check"
  fake_dep_config="$tmp/fake-config.yaml"
  cat >"$fake_dep_bin" <<'EOF'
#!/usr/bin/env bash
printf 'dependências: OK\n'
exit 0
EOF
  chmod +x "$fake_dep_bin"
  : >"$fake_dep_config"

  saved_path="$PATH"
  PATH="/usr/bin:/bin"
  validate_runtime_dependencies "$fake_dep_bin" "$fake_dep_config" "$current_user" "yes"
  PATH="$saved_path"
  pass "validação runtime resolve runuser mesmo fora do PATH do usuário"

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
