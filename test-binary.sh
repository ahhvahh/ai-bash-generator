#!/usr/bin/env bash
set -uo pipefail

# Testes de aceitação do binário compilado do projeto ai-bash-generator.
# Uso: ./test-binary.sh ./bin/amd64/ai-bash-gen
# O script não modifica o binário original.

PASS=0
FAIL=0
SKIP=0

if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_FAIL=$'\033[31m'; C_SKIP=$'\033[33m'; C_INFO=$'\033[36m'; C_RESET=$'\033[0m'
else
  C_OK=""; C_FAIL=""; C_SKIP=""; C_INFO=""; C_RESET=""
fi

pass() { PASS=$((PASS + 1)); printf '%s[PASS]%s %s\n' "$C_OK" "$C_RESET" "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '%s[FAIL]%s %s\n' "$C_FAIL" "$C_RESET" "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '%s[SKIP]%s %s\n' "$C_SKIP" "$C_RESET" "$*"; }
info() { printf '%s[INFO]%s %s\n' "$C_INFO" "$C_RESET" "$*"; }

resolve_component() {
  local name="$1" candidate
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  for candidate in "/usr/sbin/$name" "/usr/bin/$name" "/sbin/$name" "/bin/$name"; do
    [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

check_required_components() {
  local name path
  local -a required=(bash grep awk find sha256sum install getent groupadd useradd usermod runuser nologin systemctl)
  echo
  echo "---------------- Dependências/componentes ----------------"
  for name in "${required[@]}"; do
    if path="$(resolve_component "$name")"; then
      pass "componente disponível: $name ($path)"
    else
      fail "componente obrigatório ausente: $name"
    fi
  done

  if command -v dpkg-query >/dev/null 2>&1; then
    local package status
    local -a packages=(bash coreutils grep mawk passwd util-linux libc-bin systemd file binutils)
    for package in "${packages[@]}"; do
      status="$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)"
      if [[ "$status" == "install ok installed" ]]; then
        pass "pacote Debian instalado: $package"
      else
        fail "pacote Debian obrigatório ausente: $package"
      fi
    done
  else
    skip "dpkg-query indisponível; verificação de pacotes Debian ignorada"
  fi
}

usage() {
  cat <<'USAGE'
Uso:
  ./test-binary.sh <caminho-do-binario>

Exemplo:
  ./test-binary.sh ./bin/amd64/ai-bash-gen

Retorno:
  0 = todos os testes executados passaram
  1 = pelo menos um teste falhou
  2 = erro de uso
USAGE
}

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
BIN_INPUT="$1"
[[ -e "$BIN_INPUT" ]] || { echo "[ERRO] arquivo não encontrado: $BIN_INPUT" >&2; exit 2; }

BIN_DIR="$(cd -- "$(dirname -- "$BIN_INPUT")" && pwd -P)"
BIN="$BIN_DIR/$(basename -- "$BIN_INPUT")"

echo "============================================================"
echo " Teste do binário ai-bash-gen"
echo "============================================================"
info "binário: $BIN"
info "host: $(uname -s 2>/dev/null || echo '?') / $(uname -m 2>/dev/null || echo '?')"

check_required_components

[[ -f "$BIN" ]] && pass "arquivo regular existe" || fail "o caminho não é um arquivo regular"
[[ -s "$BIN" ]] && pass "arquivo não está vazio" || fail "arquivo está vazio"
[[ -x "$BIN" ]] && pass "arquivo possui permissão de execução" || fail "arquivo não possui permissão de execução"

FILE_DESC=""
BIN_ARCH="unknown"
if command -v file >/dev/null 2>&1; then
  FILE_DESC="$(file -b -- "$BIN" 2>&1)"
  info "file: $FILE_DESC"
  grep -qi 'ELF' <<<"$FILE_DESC" && pass "formato ELF reconhecido" || fail "o arquivo não foi reconhecido como ELF"

  if grep -qiE 'x86-64|x86_64' <<<"$FILE_DESC"; then BIN_ARCH="amd64"
  elif grep -qiE '80386|Intel 80386|i386' <<<"$FILE_DESC"; then BIN_ARCH="386"
  elif grep -qiE 'aarch64|ARM aarch64' <<<"$FILE_DESC"; then BIN_ARCH="arm64"
  elif grep -qiE 'ARM' <<<"$FILE_DESC"; then BIN_ARCH="arm"
  elif grep -qiE 'RISC-V' <<<"$FILE_DESC"; then BIN_ARCH="riscv64"
  elif grep -qiE 'MIPS' <<<"$FILE_DESC"; then BIN_ARCH="mips"
  elif grep -qiE 'PowerPC.*64|ppc64' <<<"$FILE_DESC"; then BIN_ARCH="ppc64"
  elif grep -qiE 'S/390|s390' <<<"$FILE_DESC"; then BIN_ARCH="s390x"
  fi
  info "arquitetura detectada: $BIN_ARCH"
else
  skip "comando 'file' não instalado"
fi

if command -v readelf >/dev/null 2>&1; then
  if readelf -h -- "$BIN" >/dev/null 2>&1; then
    pass "header ELF pode ser lido"
    MACHINE="$(readelf -h -- "$BIN" 2>/dev/null | awk -F: '/Machine:/{sub(/^[ \t]+/, "", $2); print $2; exit}')"
    [[ -n "$MACHINE" ]] && info "ELF machine: $MACHINE"
    if readelf -l -- "$BIN" 2>/dev/null | grep -q 'Requesting program interpreter'; then
      info "binário possui interpretador dinâmico"
    else
      pass "sem interpretador dinâmico ELF (compatível com CGO_ENABLED=0)"
    fi
  else
    fail "readelf não conseguiu ler o binário"
  fi
else
  skip "comando 'readelf' não instalado"
fi

if command -v sha256sum >/dev/null 2>&1; then
  info "sha256: $(sha256sum -- "$BIN" | awk '{print $1}')"
else
  skip "comando 'sha256sum' não instalado"
fi

HOST_RAW="$(uname -m 2>/dev/null || echo unknown)"
case "$HOST_RAW" in
  x86_64|amd64) HOST_ARCH="amd64" ;;
  i386|i486|i586|i686) HOST_ARCH="386" ;;
  aarch64|arm64) HOST_ARCH="arm64" ;;
  armv7l|armv6l|arm) HOST_ARCH="arm" ;;
  riscv64) HOST_ARCH="riscv64" ;;
  ppc64) HOST_ARCH="ppc64" ;;
  ppc64le) HOST_ARCH="ppc64le" ;;
  s390x) HOST_ARCH="s390x" ;;
  *) HOST_ARCH="unknown" ;;
esac

CAN_EXECUTE=0
if [[ "$BIN_ARCH" == "$HOST_ARCH" ]]; then
  CAN_EXECUTE=1
elif [[ "$HOST_ARCH" == "amd64" && "$BIN_ARCH" == "386" ]]; then
  CAN_EXECUTE=1
elif [[ "$BIN_ARCH" == "unknown" ]]; then
  CAN_EXECUTE=1
fi

RUN_STDOUT=""; RUN_STDERR=""; RUN_RC=0
run_and_capture() {
  local expected_rc="$1"; shift
  local stdout_file stderr_file rc
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  "$@" >"$stdout_file" 2>"$stderr_file"
  rc=$?
  RUN_STDOUT="$(cat "$stdout_file")"
  RUN_STDERR="$(cat "$stderr_file")"
  RUN_RC="$rc"
  rm -f -- "$stdout_file" "$stderr_file"
  [[ "$rc" -eq "$expected_rc" ]]
}

if [[ "$CAN_EXECUTE" -ne 1 ]]; then
  skip "testes funcionais: binário $BIN_ARCH não é executável diretamente no host $HOST_ARCH"
else
  echo
  echo "---------------- Testes funcionais ----------------"

  if run_and_capture 0 "$BIN" --version && grep -q '^ai-bash-gen ' <<<"$RUN_STDOUT" && grep -q '(commit ' <<<"$RUN_STDOUT"; then
    pass "--version retorna versão/commit e exit 0"
    info "--version: $RUN_STDOUT"
  else
    fail "--version não corresponde ao contrato (exit=$RUN_RC)"
  fi

  if run_and_capture 0 "$BIN" --show-paths; then
    missing=0
    for expected in \
      'config_dir=/etc/ai-bash-gen' \
      'state_dir=/var/lib/ai-bash-gen' \
      'runtime_dir=/run/ai-bash-gen' \
      'routes_dir=/run/ai-bash-gen/routes' \
      'llama_socket=/run/ai-bash-gen/internal/llama.sock' \
      'generate_socket=/run/ai-bash-gen/routes/generate.sock'
    do
      if ! grep -Fxq "$expected" <<<"$RUN_STDOUT"; then
        fail "--show-paths não contém: $expected"
        missing=1
      fi
    done
    [[ "$missing" -eq 0 ]] && pass "--show-paths retorna todos os caminhos esperados"
  else
    fail "--show-paths deveria retornar exit 0, retornou $RUN_RC"
  fi

  if run_and_capture 0 "$BIN"; then
    COMBINED="$RUN_STDOUT"$'\n'"$RUN_STDERR"
    grep -q 'Uso: ai-bash-gen' <<<"$COMBINED" && pass "execução sem argumentos mostra usage e retorna exit 0" || fail "execução sem argumentos não mostrou usage"
  else
    fail "execução sem argumentos deveria retornar exit 0, retornou $RUN_RC"
  fi

  if run_and_capture 2 "$BIN" --flag-que-nao-existe; then
    pass "flag inválida retorna exit 2"
  else
    fail "flag inválida deveria retornar exit 2, retornou $RUN_RC"
  fi

  if run_and_capture 0 "$BIN" --help; then
    if grep -q -- '--config' <<<"$RUN_STDERR$RUN_STDOUT"; then
      pass "--help expõe o modo daemon --config"
    else
      fail "--help não expõe --config"
    fi
  else
    fail "--help deveria retornar exit 0, retornou $RUN_RC"
  fi

  TMP_DIR="$(mktemp -d)"
  TMP_BIN="$TMP_DIR/ai-bash-gen"
  TEST_CONFIG="$TMP_DIR/config.yaml"
  BROKEN_CONFIG="$TMP_DIR/broken.yaml"
  FAKE_LLAMA="$TMP_DIR/llama-server"
  TEST_MODEL="$TMP_DIR/test.gguf"

  if cp -- "$BIN" "$TMP_BIN" && chmod +x "$TMP_BIN" && (cd "$TMP_DIR" && "$TMP_BIN" --version >/dev/null 2>&1 && "$TMP_BIN" --show-paths >/dev/null 2>&1); then
    pass "binário funciona fora da árvore original do projeto"
  else
    fail "binário falhou fora da árvore original"
  fi

  if run_and_capture 1 "$BIN" --config "$TMP_DIR/inexistente.yaml"; then
    pass "--config com arquivo inexistente falha com exit 1"
  else
    fail "--config inexistente deveria retornar exit 1, retornou $RUN_RC"
  fi

  cat >"$FAKE_LLAMA" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --help)
    echo '  --host HOST  bind to UNIX socket when HOST ends with .sock'
    exit 0
    ;;
  --version)
    echo 'fake llama-server'
    exit 0
    ;;
esac
exit 0
EOF
  chmod +x "$FAKE_LLAMA"
  printf 'GGUF-test\n' >"$TEST_MODEL"

  cat >"$TEST_CONFIG" <<EOF
llama:
  binary: "$FAKE_LLAMA"
  model: "$TEST_MODEL"
  context_size: 512
  startup_timeout: 1s
  request_timeout: 1s
  max_tokens: 64
  temperature: 0.1
EOF

  if run_and_capture 0 "$BIN" --config "$TEST_CONFIG" --check-dependencies; then
    grep -q '^dependências: OK' <<<"$RUN_STDOUT" && pass "--check-dependencies aprova runtime compatível" || fail "--check-dependencies não confirmou sucesso"
  else
    fail "--check-dependencies deveria retornar exit 0, retornou $RUN_RC: $RUN_STDERR"
  fi

  cat >"$BROKEN_CONFIG" <<EOF
llama:
  binary: "$TMP_DIR/nao-existe"
  model: "$TMP_DIR/nao-existe.gguf"
EOF

  if run_and_capture 1 "$BIN" --config "$BROKEN_CONFIG" --check-dependencies; then
    grep -qi 'dependências\|configuração' <<<"$RUN_STDERR" && pass "dependências ausentes bloqueiam validação" || fail "erro de dependências não foi explicado"
  else
    fail "dependências ausentes deveriam retornar exit 1, retornou $RUN_RC"
  fi

  TEST_RUNTIME="$TMP_DIR/run"
  if run_and_capture 1 env AI_BASH_GEN_RUNTIME_DIR="$TEST_RUNTIME" "$BIN" --config "$BROKEN_CONFIG"; then
    [[ ! -S "$TEST_RUNTIME/routes/generate.sock" ]] && pass "daemon não publica generate.sock quando dependências estão ausentes" || fail "generate.sock foi publicado sem dependências"
  else
    fail "daemon com dependências ausentes deveria retornar exit 1, retornou $RUN_RC"
  fi

  rm -rf -- "$TMP_DIR"
fi

echo
echo "============================================================"
echo " Resultado"
echo "============================================================"
printf 'PASS: %d\n' "$PASS"
printf 'FAIL: %d\n' "$FAIL"
printf 'SKIP: %d\n' "$SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  echo
  echo "RESULTADO: REPROVADO"
  exit 1
fi

echo
echo "RESULTADO: APROVADO"
exit 0
