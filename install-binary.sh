#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="ai-bash-gen"

DEFAULT_BIN_SOURCE=""
DEFAULT_BIN_TARGET="/usr/local/bin/${APP_NAME}"
DEFAULT_CONFIG_DIR="/etc/${APP_NAME}"
DEFAULT_STATE_DIR="/var/lib/${APP_NAME}"
DEFAULT_RUNTIME_DIR="/run/${APP_NAME}"
DEFAULT_SERVICE_USER="${APP_NAME}"
DEFAULT_SERVICE_GROUP="${APP_NAME}"
DEFAULT_UNIT_PATH="/etc/systemd/system/${APP_NAME}.service"
DEFAULT_LLAMA_TARGET="/usr/local/lib/${APP_NAME}/llama-server"
DEFAULT_MODEL_DIR="/var/lib/${APP_NAME}/models"

LLAMA_CPP_REPOSITORY="https://github.com/ggml-org/llama.cpp.git"
LLAMA_CPP_VERSION="v0.5.0"
LLAMA_CPP_COMMIT="7fe450e19305b828c199d602c23a8337aaa1f03b"

DEFAULT_MODEL_KEY="qwen35-08b-q4"
FORCE_MODE=0
BIN_ARG=""

REQUIRED_DEBIAN_PACKAGES=(bash coreutils grep mawk passwd util-linux libc-bin systemd file binutils findutils)
LLAMA_CPP_BUILD_PACKAGES=(git cmake build-essential ca-certificates)
MODEL_DOWNLOAD_PACKAGES=(curl ca-certificates)

C_RESET=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_CYAN=""
C_BOLD=""

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'
  C_BOLD=$'\033[1m'
fi

info() { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok()   { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[AVISO]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%s[ERRO]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'__USAGE__'
Instalador interativo do ai-bash-gen para Debian/Linux Desktop.

Uso:
  ./install-binary.sh
  ./install-binary.sh /caminho/para/ai-bash-gen
  ./install-binary.sh --force
  ./install-binary.sh /caminho/para/ai-bash-gen --force
  ./install-binary.sh --help

Opções:
  --force   aplica todas as opções padrão sem perguntas. Instala dependências,
            llama.cpp, modelo padrão, systemd e inicia/habilita o serviço.

Características:
  - exige terminal interativo, exceto com --force;
  - confirma cada parâmetro antes da instalação;
  - valida o binário usando --version e --show-paths, incluindo generate_socket;
  - instala o executável em /usr/local/bin por padrão;
  - usa /etc, /var/lib e /run conforme o layout definido pelo projeto;
  - cria usuário/grupo de serviço dedicados somente se solicitado;
  - só cria serviço systemd se o binário suportar --config;
  - verifica dependências Debian e oferece instalar pacotes ausentes;
  - detecta o llama-server; se estiver ausente, oferece compilar e instalar llama.cpp automaticamente;
  - usa a versão fixa v0.5.0 do llama.cpp para uma instalação reproduzível;
  - oferece um catálogo de modelos GGUF adequados a máquinas com poucos recursos;
  - baixa e verifica SHA-256 do modelo selecionado quando nenhum modelo local existe;
  - usa Qwen3.5-0.8B Q4_0 como padrão para o perfil de laptop com ~8 GB de RAM;
  - exige um llama-server compatível com Unix Socket e um modelo GGUF;
  - instala cópias controladas do llama-server e do modelo para o serviço;
  - valida as dependências novamente pelo próprio binário Go antes de iniciar;
  - cadastra e confirma o usuário cliente no grupo do serviço;
  - detecta quando a sessão atual ainda não recebeu o novo grupo;
  - valida o acesso do usuário cliente às rotas usando uma sessão nova;
  - valida caminhos absolutos antes de alterar o sistema;
  - pode iniciar/reiniciar o serviço ao final da instalação;
  - após subir o serviço, aguarda e valida os sockets públicos de routes/;
  - não altera arquivos do projeto-fonte.
__USAGE__
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-N}"
  local answer suffix

  if [[ "${FORCE_MODE:-0}" == "1" ]]; then
    case "$default" in
      Y|y) return 0 ;;
      *) return 1 ;;
    esac
  fi

  case "$default" in
    Y|y) suffix='[S/n]' ;;
    *)   suffix='[s/N]' ;;
  esac

  while true; do
    read -r -p "$prompt $suffix " answer
    answer="${answer:-$default}"
    case "$answer" in
      s|S|sim|Sim|SIM|y|Y|yes|Yes|YES) return 0 ;;
      n|N|nao|Nao|NAO|não|Não|NÃO|no|No|NO) return 1 ;;
      *) echo "Responda com 's' ou 'n'." ;;
    esac
  done
}

ask_value() {
  local prompt="$1"
  local default="$2"
  local value

  if [[ "${FORCE_MODE:-0}" == "1" ]]; then
    printf '%s' "$default"
    return 0
  fi

  read -r -p "$prompt [$default]: " value
  printf '%s' "${value:-$default}"
}
validate_absolute_path() {
  local label="$1" value="$2"

  if [[ -z "$value" ]]; then
    warn "$label não pode ser vazio."
    return 1
  fi

  if [[ "$value" != /* ]]; then
    warn "$label deve ser um caminho absoluto. Valor informado: $value"
    return 1
  fi

  return 0
}

ask_absolute_path() {
  local prompt="$1" default="$2" label="$3"
  local value

  while true; do
    value="$(ask_value "$prompt" "$default")"
    if validate_absolute_path "$label" "$value"; then
      printf '%s' "$value"
      return 0
    fi
  done
}

detect_llama_default() {
  local candidate

  if [[ -n "${AI_BASH_GEN_LLAMA_SERVER:-}" && -x "${AI_BASH_GEN_LLAMA_SERVER}" ]]; then
    printf '%s\n' "${AI_BASH_GEN_LLAMA_SERVER}"
    return 0
  fi

  if command -v llama-server >/dev/null 2>&1; then
    command -v llama-server
    return 0
  fi

  for candidate in \
    "$DEFAULT_LLAMA_TARGET" \
    "${HOME:-}/llama.cpp/build/bin/llama-server" \
    "/usr/local/bin/llama-server" \
    "/usr/bin/llama-server"
  do
    [[ -n "$candidate" && -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done

  printf '%s\n' "$DEFAULT_LLAMA_TARGET"
}

validate_llama_source() {
  local path="$1" help

  validate_absolute_path "llama-server" "$path" || return 1
  [[ -f "$path" ]] || { warn "llama-server não encontrado: $path"; return 1; }
  [[ -x "$path" ]] || { warn "llama-server não é executável: $path"; return 1; }

  help="$("$path" --help 2>&1)" || { warn "llama-server falhou ao executar --help: $path"; return 1; }
  grep -q -- '--host' <<<"$help" || { warn "llama-server não expõe --host."; return 1; }
  if ! grep -Eqi 'unix|\.sock' <<<"$help"; then
    warn "não foi identificado suporte a Unix Socket no llama-server."
    return 1
  fi
  return 0
}

ask_llama_source() {
  local default="$1" value
  while true; do
    value="$(ask_value 'Caminho do llama-server existente' "$default")"
    if validate_llama_source "$value"; then
      printf '%s' "$value"
      return 0
    fi
  done
}

detect_model_default() {
  local dir found
  for dir in \
    "$DEFAULT_MODEL_DIR" \
    "${HOME:-}/.cache/llama.cpp" \
    "${HOME:-}/models" \
    "$PWD"
  do
    [[ -d "$dir" ]] || continue
    found="$(find "$dir" -maxdepth 3 -type f -name '*.gguf' -print -quit 2>/dev/null || true)"
    [[ -n "$found" ]] && { printf '%s\n' "$found"; return 0; }
  done
  printf '%s\n' "$DEFAULT_MODEL_DIR/model.gguf"
}

validate_model_source() {
  local path="$1" magic
  validate_absolute_path "modelo GGUF" "$path" || return 1
  [[ "$path" == *.gguf || "$path" == *.GGUF ]] || { warn "o modelo deve possuir extensão .gguf: $path"; return 1; }
  [[ -f "$path" ]] || { warn "modelo GGUF não encontrado: $path"; return 1; }
  [[ -s "$path" ]] || { warn "modelo GGUF está vazio: $path"; return 1; }
  [[ -r "$path" ]] || { warn "modelo GGUF não pode ser lido: $path"; return 1; }
  magic="$(LC_ALL=C head -c 4 -- "$path" 2>/dev/null || true)"
  [[ "$magic" == "GGUF" ]] || { warn "arquivo não possui assinatura GGUF válida: $path"; return 1; }
  return 0
}

ask_model_source() {
  local default="$1" value
  while true; do
    value="$(ask_value 'Caminho do modelo GGUF existente' "$default")"
    if validate_model_source "$value"; then
      printf '%s' "$value"
      return 0
    fi
  done
}

model_catalog_resolve() {
  local key="$1"
  case "$key" in
    qwen35-08b-q4)
      MODEL_KEY="$key"
      MODEL_LABEL="Qwen3.5-0.8B Q4_0"
      MODEL_FILE="Qwen3.5-0.8B-Q4_0.gguf"
      MODEL_SIZE="563 MB"
      MODEL_URL="https://huggingface.co/ggml-org/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_0.gguf"
      MODEL_SHA256="57d1997790d1744fba5b40a7317df71ea5e2acee28c47e78f0cce39c0703f8cf"
      MODEL_NOTE="padrão: atual, leve e adequado para CPU com ~8 GB RAM"
      ;;
    qwen35-08b-q8)
      MODEL_KEY="$key"
      MODEL_LABEL="Qwen3.5-0.8B Q8_0"
      MODEL_FILE="Qwen3.5-0.8B-Q8_0.gguf"
      MODEL_SIZE="834 MB"
      MODEL_URL="https://huggingface.co/ggml-org/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q8_0.gguf"
      MODEL_SHA256="37ae482d336108d23516fa35e8e0c4126688d81018b87178a18d752a1357814f"
      MODEL_NOTE="mesmo modelo com quantização maior; mais memória e I/O"
      ;;
    qwen25-coder-15b-q4)
      MODEL_KEY="$key"
      MODEL_LABEL="Qwen2.5-Coder-1.5B-Instruct Q4_K_M"
      MODEL_FILE="qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
      MODEL_SIZE="1.12 GB"
      MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/38f6bab61d341b23a6c00226f32c0d6148bf9f43/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
      MODEL_SHA256="cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046"
      MODEL_NOTE="especializado em código; mais antigo, porém alinhado ao objetivo do projeto"
      ;;
    qwen35-4b-q4)
      MODEL_KEY="$key"
      MODEL_LABEL="Qwen3.5-4B Q4_K_M"
      MODEL_FILE="Qwen_Qwen3.5-4B-Q4_K_M.gguf"
      MODEL_SIZE="2.87 GB"
      MODEL_URL="https://huggingface.co/bartowski/Qwen_Qwen3.5-4B-GGUF/resolve/158c77ecbedcdc9cf2011783a420757be1e45c15/Qwen_Qwen3.5-4B-Q4_K_M.gguf"
      MODEL_SHA256="2c08bf55fdde0b2e4bd52fa7dc6d49150e83eac997910cf014b7221c172a4b20"
      MODEL_NOTE="mais capaz, mas significativamente mais lento em CPU de laptop"
      ;;
    *) return 1 ;;
  esac
}

print_hardware_profile() {
  local cpu threads mem_kb mem_gb
  cpu="$(awk -F: '/model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
  threads="$(nproc 2>/dev/null || printf '?')"
  mem_kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
  mem_gb="?"
  if [[ "$mem_kb" =~ ^[0-9]+$ ]]; then
    mem_gb="$(( (mem_kb + 524288) / 1048576 ))"
  fi
  info "hardware detectado: CPU=${cpu:-não confirmada}; threads=$threads; RAM≈${mem_gb} GB"
}

print_model_catalog() {
  local key
  echo
  printf '%sModelos GGUF disponíveis%s\n' "$C_BOLD" "$C_RESET"
  print_hardware_profile
  for key in qwen35-08b-q4 qwen35-08b-q8 qwen25-coder-15b-q4 qwen35-4b-q4; do
    model_catalog_resolve "$key"
    case "$key" in
      qwen35-08b-q4) printf '  1) %s — %s — %s [PADRÃO]\n' "$MODEL_LABEL" "$MODEL_SIZE" "$MODEL_NOTE" ;;
      qwen35-08b-q8) printf '  2) %s — %s — %s\n' "$MODEL_LABEL" "$MODEL_SIZE" "$MODEL_NOTE" ;;
      qwen25-coder-15b-q4) printf '  3) %s — %s — %s\n' "$MODEL_LABEL" "$MODEL_SIZE" "$MODEL_NOTE" ;;
      qwen35-4b-q4) printf '  4) %s — %s — %s\n' "$MODEL_LABEL" "$MODEL_SIZE" "$MODEL_NOTE" ;;
    esac
  done
  echo "  5) Informar caminho de um modelo GGUF já existente"
}

download_selected_model() {
  local state_dir="$1"
  local model_dir="$state_dir/models"
  local target="$model_dir/model.gguf"
  local partial="$model_dir/.model.gguf.part"
  local actual_sha

  ensure_debian_package_list "download de modelos GGUF" "${MODEL_DOWNLOAD_PACKAGES[@]}"
  command -v curl >/dev/null 2>&1 || die "curl não encontrado após instalação das dependências de download."

  if mkdir -p -- "$model_dir" 2>/dev/null && [[ -w "$model_dir" ]]; then
    chmod 0755 "$model_dir" 2>/dev/null || true
  else
    "${SUDO[@]}" install -d -o root -g root -m 0755 "$model_dir"
  fi

  info "baixando $MODEL_LABEL ($MODEL_SIZE)"
  info "origem: $MODEL_URL"
  info "destino: $target"
  "${SUDO[@]}" curl --fail --location --retry 3 --retry-delay 2 --continue-at - \
    --output "$partial" "$MODEL_URL" || die "falha ao baixar o modelo $MODEL_LABEL."

  actual_sha="$("${SUDO[@]}" sha256sum "$partial" | awk '{print $1}')"
  [[ "$actual_sha" == "$MODEL_SHA256" ]] || {
    "${SUDO[@]}" rm -f -- "$partial"
    die "SHA-256 inválido para $MODEL_LABEL. Esperado=$MODEL_SHA256 obtido=$actual_sha"
  }

  "${SUDO[@]}" mv -f -- "$partial" "$target"
  "${SUDO[@]}" chmod 0644 "$target"

  validate_model_source "$target" || die "modelo baixado falhou na validação GGUF: $target"

  {
    printf 'key=%s\n' "$MODEL_KEY"
    printf 'label=%s\n' "$MODEL_LABEL"
    printf 'source=%s\n' "$MODEL_URL"
    printf 'sha256=%s\n' "$MODEL_SHA256"
  } | "${SUDO[@]}" tee "$model_dir/model.info" >/dev/null
  "${SUDO[@]}" chmod 0644 "$model_dir/model.info"

  MODEL_SOURCE="$target"
  MODEL_INSTALLATION_MODE="downloaded"
  ok "modelo instalado e verificado: $MODEL_SOURCE"
}

select_or_download_model() {
  local state_dir="$1"
  local detected choice key

  detected="$(detect_model_default)"
  if validate_model_source "$detected" >/dev/null 2>&1; then
    if ask_yes_no "Modelo GGUF local encontrado em $detected. Usar este modelo?" "Y"; then
      MODEL_SOURCE="$detected"
      MODEL_INSTALLATION_MODE="existing"
      return 0
    fi
  fi

  if [[ "${FORCE_MODE:-0}" == "1" ]]; then
    model_catalog_resolve "$DEFAULT_MODEL_KEY" || die "modelo padrão inválido: $DEFAULT_MODEL_KEY"
    download_selected_model "$state_dir"
    return 0
  fi

  while true; do
    print_model_catalog
    choice="$(ask_value 'Selecione o modelo' '1')"
    case "$choice" in
      1) key="qwen35-08b-q4" ;;
      2) key="qwen35-08b-q8" ;;
      3) key="qwen25-coder-15b-q4" ;;
      4) key="qwen35-4b-q4" ;;
      5)
        MODEL_SOURCE="$(ask_model_source "$detected")"
        MODEL_INSTALLATION_MODE="manual"
        return 0
        ;;
      *) warn "opção de modelo inválida: $choice"; continue ;;
    esac

    model_catalog_resolve "$key" || die "entrada inválida no catálogo de modelos: $key"
    printf '\nSelecionado: %s (%s)\n%s\n' "$MODEL_LABEL" "$MODEL_SIZE" "$MODEL_NOTE"
    if ask_yes_no "Baixar este modelo agora?" "Y"; then
      download_selected_model "$state_dir"
      return 0
    fi
  done
}

confirm_value() {
  local label="$1"
  local value="$2"

  if [[ "${FORCE_MODE:-0}" == "1" ]]; then
    info "$label: $value"
    return 0
  fi

  printf '\n%s%s%s\n' "$C_BOLD" "$label" "$C_RESET"
  printf '  %s\n' "$value"
  ask_yes_no "Confirmar este valor?" "Y" || die "instalação cancelada pelo usuário."
}

require_interactive() {
  [[ "${FORCE_MODE:-0}" == "1" ]] && return 0
  [[ -t 0 && -t 1 ]] || die "este instalador exige um terminal interativo; use --force para instalação não interativa."
}

check_debian_family() {
  local id="" like="" pretty="desconhecido"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    like="${ID_LIKE:-}"
    pretty="${PRETTY_NAME:-${NAME:-desconhecido}}"
  fi

  info "sistema detectado: $pretty"

  if [[ "$id" != "debian" && " $like " != *" debian "* ]]; then
    warn "o sistema não foi identificado como Debian ou derivado."
    ask_yes_no "Continuar mesmo assim?" "N" || die "instalação cancelada."
  fi
}

setup_privilege_command() {
  if [[ "$EUID" -eq 0 ]]; then
    SUDO=()
    info "execução como root; sudo não será usado."
    return
  fi

  command -v sudo >/dev/null 2>&1 || die "sudo não encontrado. Execute como root ou instale/configure sudo."
  SUDO=(sudo)
  info "operações administrativas usarão sudo."
}
package_installed() {
  local package="$1"
  command -v dpkg-query >/dev/null 2>&1 || return 1
  dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fxq 'install ok installed'
}

ensure_debian_package_list() {
  local label="$1"
  shift
  local package
  local -a requested=("$@")
  local -a missing=()

  if ! command -v dpkg-query >/dev/null 2>&1; then
    warn "dpkg-query não encontrado; não é possível validar os pacotes de $label."
    return 0
  fi

  for package in "${requested[@]}"; do
    package_installed "$package" || missing+=("$package")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "$label disponíveis: ${requested[*]}"
    return 0
  fi

  warn "$label ausentes: ${missing[*]}"
  command -v apt-get >/dev/null 2>&1 || die "apt-get não encontrado; instale manualmente: ${missing[*]}"

  ask_yes_no "Instalar os pacotes necessários para $label agora?" "Y" || {
    die "dependências obrigatórias ausentes para $label: ${missing[*]}"
  }

  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" apt-get install -y -- "${missing[@]}"
  ok "$label instaladas."
}

ensure_debian_packages() {
  ensure_debian_package_list "dependências Debian do ai-bash-gen" "${REQUIRED_DEBIAN_PACKAGES[@]}"
}

llama_build_jobs() {
  local jobs mem_kb
  jobs="$(nproc 2>/dev/null || printf '1')"
  [[ "$jobs" =~ ^[0-9]+$ ]] || jobs=1
  (( jobs < 1 )) && jobs=1
  (( jobs > 4 )) && jobs=4

  mem_kb="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)"
  if [[ "$mem_kb" =~ ^[0-9]+$ ]]; then
    if (( mem_kb < 5000000 )); then
      jobs=1
    elif (( mem_kb < 10000000 && jobs > 2 )); then
      jobs=2
    fi
  fi

  printf '%s\n' "$jobs"
}

install_llama_cpp_from_source() {
  local target="${1:-$DEFAULT_LLAMA_TARGET}"
  local temp_dir source_dir build_dir built_binary jobs actual_commit
  local rc=0

  ensure_debian_package_list "compilação do llama.cpp" "${LLAMA_CPP_BUILD_PACKAGES[@]}"

  command -v git >/dev/null 2>&1 || die "git não encontrado após instalação das dependências do llama.cpp."
  command -v cmake >/dev/null 2>&1 || die "cmake não encontrado após instalação das dependências do llama.cpp."
  command -v c++ >/dev/null 2>&1 || die "compilador C++ não encontrado após instalação de build-essential."

  temp_dir="$(mktemp -d)"
  source_dir="$temp_dir/llama.cpp"
  build_dir="$source_dir/build"
  jobs="$(llama_build_jobs)"

  info "instalando llama.cpp $LLAMA_CPP_VERSION para fornecer llama-server."
  info "fonte oficial: $LLAMA_CPP_REPOSITORY"
  info "commit fixado: $LLAMA_CPP_COMMIT"
  info "compilação CPU local: $jobs job(s); esta etapa pode levar alguns minutos."

  set +e
  (
    set -Eeuo pipefail
    export GIT_TERMINAL_PROMPT=0

    git init -q "$source_dir"
    git -C "$source_dir" remote add origin "$LLAMA_CPP_REPOSITORY"
    git -C "$source_dir" fetch --quiet --depth 1 origin "refs/tags/$LLAMA_CPP_VERSION:refs/tags/$LLAMA_CPP_VERSION"
    actual_commit="$(git -C "$source_dir" rev-list -n 1 "$LLAMA_CPP_VERSION")"
    git -C "$source_dir" checkout --quiet --detach "$actual_commit"

    [[ "$actual_commit" == "$LLAMA_CPP_COMMIT" ]] || {
      echo "[ERRO] commit recebido do llama.cpp não corresponde ao commit fixado." >&2
      exit 1
    }

    cmake -S "$source_dir" -B "$build_dir" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DGGML_NATIVE=ON \
      -DLLAMA_BUILD_COMMON=ON \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_BUILD_TOOLS=ON \
      -DLLAMA_BUILD_SERVER=ON \
      -DLLAMA_BUILD_APP=OFF \
      -DLLAMA_BUILD_UI=OFF \
      -DLLAMA_USE_PREBUILT_UI=OFF \
      -DLLAMA_OPENSSL=OFF

    cmake --build "$build_dir" --config Release --target llama-server -j "$jobs"

    built_binary="$build_dir/bin/llama-server"
    [[ -x "$built_binary" ]] || {
      echo "[ERRO] compilação terminou sem gerar $built_binary" >&2
      exit 1
    }

    "$built_binary" --help >/dev/null 2>&1
    "${SUDO[@]}" install -d -o root -g root -m 0755 "$(dirname -- "$target")"
    "${SUDO[@]}" install -o root -g root -m 0755 "$built_binary" "$target"
  )
  rc=$?
  set -e

  rm -rf -- "$temp_dir"

  [[ "$rc" -eq 0 ]] || die "falha ao compilar/instalar llama.cpp $LLAMA_CPP_VERSION."
  validate_llama_source "$target" || die "llama-server instalado, mas a validação de compatibilidade falhou: $target"

  ok "llama.cpp $LLAMA_CPP_VERSION instalado: $target"
}

ensure_llama_server_available() {
  local detected

  detected="$(detect_llama_default)"
  if validate_llama_source "$detected" >/dev/null 2>&1; then
    LLAMA_SOURCE="$detected"
    LLAMA_INSTALLATION_MODE="existing"
    ok "llama-server compatível detectado: $LLAMA_SOURCE"
    return 0
  fi

  warn "llama-server não foi encontrado ou não é compatível."
  info "o ai-bash-gen usa o llama-server do projeto oficial llama.cpp."
  info "o instalador pode baixar o código-fonte fixado em $LLAMA_CPP_VERSION e compilar somente o servidor para esta máquina."

  if ask_yes_no "Instalar llama.cpp $LLAMA_CPP_VERSION agora?" "Y"; then
    install_llama_cpp_from_source "$DEFAULT_LLAMA_TARGET"
    LLAMA_SOURCE="$DEFAULT_LLAMA_TARGET"
    LLAMA_INSTALLATION_MODE="installed"
    return 0
  fi

  warn "a instalação automática do llama.cpp foi recusada."
  LLAMA_SOURCE="$(ask_llama_source "$detected")"
  LLAMA_INSTALLATION_MODE="manual"
}

detect_client_user() {
  local candidate=""

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    candidate="$SUDO_USER"
  elif [[ "$EUID" -ne 0 ]]; then
    candidate="$(id -un)"
  elif command -v logname >/dev/null 2>&1; then
    candidate="$(logname 2>/dev/null || true)"
    [[ "$candidate" == "root" ]] && candidate=""
  fi

  printf '%s\n' "$candidate"
}

user_has_registered_group() {
  local user="$1" group="$2"
  id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -Fxq "$group"
}

session_user_has_group() {
  local user="$1" group="$2"
  local current_user target_uid group_gid pid proc_uid proc_gid proc_ppid groups_line

  current_user="$(id -un 2>/dev/null || true)"
  if [[ "$current_user" == "$user" ]]; then
    id -nG 2>/dev/null | tr ' ' '\n' | grep -Fxq "$group"
    return $?
  fi

  # Se o instalador inteiro foi iniciado via sudo, procure a sessão
  # original do SUDO_USER na árvore de processos.
  if [[ "$EUID" -ne 0 || "${SUDO_USER:-}" != "$user" ]]; then
    return 2
  fi

  target_uid="$(id -u "$user" 2>/dev/null)" || return 2
  group_gid="$(getent group "$group" 2>/dev/null | awk -F: '{print $3; exit}')"
  [[ -n "$group_gid" ]] || return 2

  pid="${BASHPID:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 2

  while [[ "$pid" -gt 1 && -r "/proc/$pid/status" ]]; do
    proc_uid="$(awk '/^Uid:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null || true)"
    if [[ "$proc_uid" == "$target_uid" ]]; then
      proc_gid="$(awk '/^Gid:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null || true)"
      [[ "$proc_gid" == "$group_gid" ]] && return 0

      groups_line="$(awk '/^Groups:/ {$1=""; sub(/^ /, ""); print; exit}' "/proc/$pid/status" 2>/dev/null || true)"
      tr ' ' '\n' <<<"$groups_line" | grep -Fxq "$group_gid"
      return $?
    fi

    proc_ppid="$(awk '/^PPid:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null || true)"
    [[ "$proc_ppid" =~ ^[0-9]+$ ]] || return 2
    pid="$proc_ppid"
  done

  return 2
}
check_client_session_group() {
  local user="$1" group="$2" rc

  CLIENT_SESSION_REFRESH_REQUIRED="no"
  if session_user_has_group "$user" "$group"; then
    ok "sessão atual de $user já possui o grupo $group."
    return 0
  else
    rc=$?
  fi

  if [[ "$rc" -eq 1 ]]; then
    CLIENT_SESSION_REFRESH_REQUIRED="yes"
    warn "o cadastro de $user no grupo $group está correto, mas a sessão atual ainda não recebeu esse grupo."
    warn "para usar o cliente agora, execute em um novo shell: newgrp $group"
    warn "para corrigir permanentemente a sessão gráfica/SSH, faça logout e login novamente."
    return 0
  fi

  CLIENT_SESSION_REFRESH_REQUIRED="unknown"
  warn "não foi possível identificar uma sessão ativa de $user para confirmar os grupos já carregados."
  warn "se o acesso ao socket falhar, faça logout/login ou execute: newgrp $group"
}
authorize_client_user() {
  local user="$1" group="$2" usermod_cmd

  [[ -n "$user" ]] || return 0
  id "$user" >/dev/null 2>&1 || die "usuário cliente não existe: $user"
  getent group "$group" >/dev/null 2>&1 || die "grupo de serviço não existe: $group"

  usermod_cmd="$(resolve_system_command usermod)" || {
    die "usermod não encontrado. No Debian, ele é fornecido pelo pacote 'passwd'."
  }

  if user_has_registered_group "$user" "$group"; then
    info "usuário $user já está cadastrado no grupo $group"
  else
    "${SUDO[@]}" "$usermod_cmd" -aG "$group" "$user"
    ok "usuário $user adicionado ao grupo $group"
  fi

  if ! user_has_registered_group "$user" "$group"; then
    die "o cadastro de $user no grupo $group não foi efetivado."
  fi
  ok "cadastro confirmado: $user pertence ao grupo $group."

  check_client_session_group "$user" "$group"
}
load_existing_unit_defaults() {
  local existing_user existing_group
  [[ -r "$DEFAULT_UNIT_PATH" ]] || return 0

  existing_user="$(awk -F= '$1 == "User" {print $2; exit}' "$DEFAULT_UNIT_PATH" 2>/dev/null || true)"
  existing_group="$(awk -F= '$1 == "Group" {print $2; exit}' "$DEFAULT_UNIT_PATH" 2>/dev/null || true)"

  if [[ -n "$existing_user" ]]; then
    DEFAULT_SERVICE_USER="$existing_user"
  fi
  if [[ -n "$existing_group" ]]; then
    DEFAULT_SERVICE_GROUP="$existing_group"
  fi

  if [[ -n "$existing_user" || -n "$existing_group" ]]; then
    info "unit existente detectada: $DEFAULT_UNIT_PATH"
    info "identidade preservada como padrão: user=$DEFAULT_SERVICE_USER group=$DEFAULT_SERVICE_GROUP"
  fi
}

absolute_path() {
  local p="$1"
  local d b
  d="$(cd -- "$(dirname -- "$p")" && pwd -P)"
  b="$(basename -- "$p")"
  printf '%s/%s\n' "$d" "$b"
}

detect_binary_default() {
  local root arch candidate
  root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

  case "$(uname -m 2>/dev/null || true)" in
    x86_64|amd64) arch="amd64" ;;
    i386|i486|i586|i686) arch="386" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l|armv6l|arm) arch="arm" ;;
    riscv64) arch="riscv64" ;;
    ppc64) arch="ppc64" ;;
    ppc64le) arch="ppc64le" ;;
    s390x) arch="s390x" ;;
    *) arch="" ;;
  esac

  if [[ -n "$arch" ]]; then
    candidate="$root/bin/$arch/$APP_NAME"
    [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
  fi

  candidate="$root/$APP_NAME"
  [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return; }

  printf './bin/amd64/%s\n' "$APP_NAME"
}

validate_binary() {
  local bin="$1"
  local version_output paths_output file_output

  [[ -f "$bin" ]] || die "binário não encontrado: $bin"
  [[ -s "$bin" ]] || die "binário vazio: $bin"

  if [[ ! -x "$bin" ]]; then
    warn "o binário não possui permissão de execução."
    ask_yes_no "Aplicar chmod +x no binário de origem?" "Y" || die "binário não executável."
    chmod +x -- "$bin"
  fi

  if command -v file >/dev/null 2>&1; then
    file_output="$(file -b -- "$bin")"
    info "arquivo: $file_output"
    grep -qi 'ELF' <<<"$file_output" || warn "o arquivo não foi identificado como ELF Linux."
  fi

  version_output="$("$bin" --version 2>&1)" || die "falha ao executar '$bin --version'."
  [[ "$version_output" == ai-bash-gen\ * ]] || die "o arquivo não parece ser o ai-bash-gen: $version_output"
  info "versão detectada: $version_output"

  paths_output="$("$bin" --show-paths 2>&1)" || die "falha ao executar '$bin --show-paths'."

  grep -Fxq "config_dir=$DEFAULT_CONFIG_DIR" <<<"$paths_output" || die "config_dir do binário não corresponde a $DEFAULT_CONFIG_DIR"
  grep -Fxq "state_dir=$DEFAULT_STATE_DIR" <<<"$paths_output" || die "state_dir do binário não corresponde a $DEFAULT_STATE_DIR"
  grep -Fxq "runtime_dir=$DEFAULT_RUNTIME_DIR" <<<"$paths_output" || die "runtime_dir do binário não corresponde a $DEFAULT_RUNTIME_DIR"
  grep -Fxq "routes_dir=$DEFAULT_RUNTIME_DIR/routes" <<<"$paths_output" || die "routes_dir do binário não corresponde ao layout esperado"
  grep -Fxq "llama_socket=$DEFAULT_RUNTIME_DIR/internal/llama.sock" <<<"$paths_output" || die "llama_socket do binário não corresponde ao layout esperado"
  grep -Fxq "generate_socket=$DEFAULT_RUNTIME_DIR/routes/generate.sock" <<<"$paths_output" || die "generate_socket ausente ou incompatível; o binário não contém a entrada de geração esperada"

  ok "binário validado."
}

supports_daemon_mode() {
  local bin="$1" help
  help="$("$bin" --help 2>&1 || true)"
  grep -q -- '--config' <<<"$help"
}

resolve_system_command() {
  local name="$1" candidate

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  for candidate in "/usr/sbin/$name" "/usr/bin/$name" "/sbin/$name" "/bin/$name"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

create_service_account() {
  local user="$1" group="$2" home="$3"
  local groupadd_cmd useradd_cmd nologin_shell

  # Debian instala groupadd/useradd normalmente em /usr/sbin.
  # Resolva os caminhos antes de qualquer alteração para não depender do PATH.
  groupadd_cmd="$(resolve_system_command groupadd)" || {
    die "groupadd não encontrado. No Debian, ele é fornecido pelo pacote 'passwd'. Instale com: sudo apt install passwd"
  }

  useradd_cmd="$(resolve_system_command useradd)" || {
    die "useradd não encontrado. No Debian, ele é fornecido pelo pacote 'passwd'. Instale com: sudo apt install passwd"
  }

  if nologin_shell="$(resolve_system_command nologin 2>/dev/null)"; then
    :
  elif [[ -x /usr/sbin/nologin ]]; then
    nologin_shell="/usr/sbin/nologin"
  else
    die "shell nologin não encontrada em um caminho padrão Debian."
  fi

  info "groupadd: $groupadd_cmd"
  info "useradd:  $useradd_cmd"

  if getent group "$group" >/dev/null 2>&1; then
    info "grupo já existe: $group"
  else
    "${SUDO[@]}" "$groupadd_cmd" --system "$group"
    ok "grupo criado: $group"
  fi

  if id "$user" >/dev/null 2>&1; then
    info "usuário já existe: $user"
  else
    "${SUDO[@]}" "$useradd_cmd" \
      --system \
      --gid "$group" \
      --home-dir "$home" \
      --no-create-home \
      --shell "$nologin_shell" \
      "$user"
    ok "usuário criado: $user"
  fi
}
install_binary() {
  local source="$1" target="$2"
  local target_dir backup

  target_dir="$(dirname -- "$target")"
  "${SUDO[@]}" install -d -o root -g root -m 0755 "$target_dir"

  if [[ -e "$target" ]]; then
    warn "já existe um binário instalado em: $target"
    if command -v sha256sum >/dev/null 2>&1; then
      info "SHA-256 atual: $(sha256sum -- "$target" 2>/dev/null | awk '{print $1}' || true)"
      info "SHA-256 novo : $(sha256sum -- "$source" | awk '{print $1}')"
    fi

    ask_yes_no "Substituir o binário existente?" "N" || die "instalação cancelada."

    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    "${SUDO[@]}" cp -a -- "$target" "$backup"
    info "backup criado: $backup"
  fi

  "${SUDO[@]}" install -o root -g root -m 0755 -- "$source" "$target"
  ok "binário instalado em $target"
}

prepare_directories() {
  local config_dir="$1" state_dir="$2" runtime_dir="$3"
  local owner_user="$4" owner_group="$5" use_service_user="$6"

  "${SUDO[@]}" install -d -o root -g root -m 0755 "$config_dir"

  if [[ "$use_service_user" == "yes" ]]; then
    "${SUDO[@]}" install -d -o "$owner_user" -g "$owner_group" -m 0750 "$state_dir"
    "${SUDO[@]}" install -d -o "$owner_user" -g "$owner_group" -m 0750 "$runtime_dir"
    "${SUDO[@]}" install -d -o "$owner_user" -g "$owner_group" -m 0750 "$runtime_dir/routes"
    "${SUDO[@]}" install -d -o "$owner_user" -g "$owner_group" -m 0700 "$runtime_dir/internal"
  else
    "${SUDO[@]}" install -d -o root -g root -m 0755 "$state_dir"
    "${SUDO[@]}" install -d -o root -g root -m 0755 "$runtime_dir"
    "${SUDO[@]}" install -d -o root -g root -m 0755 "$runtime_dir/routes"
    "${SUDO[@]}" install -d -o root -g root -m 0700 "$runtime_dir/internal"
  fi

  ok "diretórios preparados."
}


create_bootstrap_config() {
  local config_dir="$1" group="$2" llama_binary="$3" model_file="$4"
  local config_file temp_config
  config_file="$config_dir/config.yaml"

  if [[ -e "$config_file" ]]; then
    info "configuração existente preservada: $config_file"
    return 0
  fi

  temp_config="$(mktemp)"
  cat >"$temp_config" <<__CONFIG__
# ai-bash-gen - configuração bootstrap
llama:
  binary: "$llama_binary"
  model: "$model_file"
  context_size: 2048
  startup_timeout: 2m
  request_timeout: 3m
  max_tokens: 1536
  temperature: 0.2
__CONFIG__

  "${SUDO[@]}" install -o root -g "$group" -m 0640 "$temp_config" "$config_file"
  rm -f -- "$temp_config"
  ok "configuração bootstrap criada em $config_file"
}

install_runtime_assets() {
  local llama_source="$1" llama_target="$2" model_source="$3" model_target="$4"
  local owner_user="$5" owner_group="$6" use_service_user="$7"
  local model_dir

  model_dir="$(dirname -- "$model_target")"
  "${SUDO[@]}" install -d -o root -g root -m 0755 "$(dirname -- "$llama_target")"
  if [[ "$(readlink -f -- "$llama_source")" != "$(readlink -m -- "$llama_target")" ]]; then
    "${SUDO[@]}" install -o root -g root -m 0755 "$llama_source" "$llama_target"
  else
    info "llama-server já está no destino controlado: $llama_target"
  fi

  if [[ "$use_service_user" == "yes" ]]; then
    "${SUDO[@]}" install -d -o "$owner_user" -g "$owner_group" -m 0750 "$model_dir"
  else
    "${SUDO[@]}" install -d -o root -g root -m 0755 "$model_dir"
  fi

  if [[ "$(readlink -f -- "$model_source")" != "$(readlink -m -- "$model_target")" ]]; then
    info "copiando modelo GGUF para $model_target; arquivos grandes podem levar alguns minutos..."
    "${SUDO[@]}" cp --reflink=auto --sparse=always -- "$model_source" "$model_target"
  fi

  if [[ "$use_service_user" == "yes" ]]; then
    "${SUDO[@]}" chown "$owner_user:$owner_group" "$model_target"
    "${SUDO[@]}" chmod 0640 "$model_target"
  else
    "${SUDO[@]}" chown root:root "$model_target"
    "${SUDO[@]}" chmod 0644 "$model_target"
  fi

  ok "llama-server instalado em $llama_target"
  ok "modelo GGUF disponível em $model_target"
}

validate_runtime_dependencies() {
  local bin="$1" config_file="$2" service_user="$3" use_service_user="$4"
  local output runuser_cmd

  if [[ "$use_service_user" == "yes" ]]; then
    runuser_cmd="$(resolve_system_command runuser)" || {
      die "runuser não encontrado. No Debian, ele é fornecido pelo pacote util-linux."
    }
    info "runuser: $runuser_cmd"
    output="$("${SUDO[@]}" "$runuser_cmd" -u "$service_user" -- "$bin" --config "$config_file" --check-dependencies 2>&1)" ||
      die "validação Go das dependências falhou para o usuário de serviço: $output"
  else
    output="$("$bin" --config "$config_file" --check-dependencies 2>&1)" ||
      die "validação Go das dependências falhou: $output"
  fi
  info "$output"
  ok "dependências de runtime validadas pelo binário Go."
}

create_systemd_unit() {
  local unit_path="$1" bin_target="$2" config_dir="$3" runtime_dir="$4" user="$5" group="$6"
  local temp_unit

  temp_unit="$(mktemp)"
  cat >"$temp_unit" <<__UNIT__
[Unit]
Description=AI Bash Generator
After=local-fs.target

[Service]
Type=simple
User=$user
Group=$group
Environment=AI_BASH_GEN_RUNTIME_DIR=$runtime_dir
ExecStart=$bin_target --config $config_dir/config.yaml
Restart=on-failure
RestartSec=2s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ai-bash-gen

NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX
LockPersonality=yes
MemoryDenyWriteExecute=no

StateDirectory=$APP_NAME
RuntimeDirectory=$APP_NAME
RuntimeDirectoryMode=0750
StateDirectoryMode=0750

[Install]
WantedBy=multi-user.target
__UNIT__

  "${SUDO[@]}" install -o root -g root -m 0644 "$temp_unit" "$unit_path"
  rm -f -- "$temp_unit"
  "${SUDO[@]}" systemctl daemon-reload
  ok "unit instalada em $unit_path"
}

discover_route_sockets() {
  local bin="$1" runtime_dir="$2"
  local key value

  AI_BASH_GEN_RUNTIME_DIR="$runtime_dir" "$bin" --show-paths 2>/dev/null | while IFS='=' read -r key value; do
    [[ "$key" == *_socket ]] || continue
    [[ "$value" == "$runtime_dir/routes/"* ]] || continue
    printf '%s|%s\n' "$key" "$value"
  done
}

print_service_diagnostics() {
  warn "diagnóstico do serviço $APP_NAME:"
  "${SUDO[@]}" systemctl status "$APP_NAME" --no-pager -l >&2 || true
  "${SUDO[@]}" journalctl -u "$APP_NAME" -n 30 --no-pager -l >&2 || true
}

validate_published_routes() {
  local bin="$1" runtime_dir="$2" expected_group="$3"
  local timeout_seconds="${4:-10}"
  local routes_dir="$runtime_dir/routes"
  local attempts entry key socket mode group missing i
  local -a routes=()

  mapfile -t routes < <(discover_route_sockets "$bin" "$runtime_dir")
  [[ ${#routes[@]} -gt 0 ]] || die "o binário não declarou sockets públicos em $routes_dir"

  attempts=$((timeout_seconds * 4))
  info "aguardando até ${timeout_seconds}s pelas rotas públicas..."

  for ((i=1; i<=attempts; i++)); do
    if "${SUDO[@]}" systemctl is-active --quiet "$APP_NAME"; then
      missing=0
      for entry in "${routes[@]}"; do
        IFS='|' read -r key socket <<<"$entry"
        if ! "${SUDO[@]}" test -S "$socket"; then
          missing=1
          break
        fi
      done
      [[ "$missing" -eq 0 ]] && break
    fi
    sleep 0.25
  done

  if ! "${SUDO[@]}" systemctl is-active --quiet "$APP_NAME"; then
    print_service_diagnostics
    die "o serviço $APP_NAME não permaneceu ativo após a inicialização."
  fi

  if ! "${SUDO[@]}" test -d "$routes_dir"; then
    print_service_diagnostics
    die "diretório de rotas não foi criado: $routes_dir"
  fi

  if command -v stat >/dev/null 2>&1; then
    mode="$("${SUDO[@]}" stat -c '%a' "$routes_dir" 2>/dev/null || true)"
    group="$("${SUDO[@]}" stat -c '%G' "$routes_dir" 2>/dev/null || true)"
    [[ "$mode" == "750" ]] || die "permissão inesperada em $routes_dir: esperado 0750, encontrado ${mode:-?}"
    [[ "$group" == "$expected_group" ]] || die "grupo inesperado em $routes_dir: esperado $expected_group, encontrado ${group:-?}"
  fi

  for entry in "${routes[@]}"; do
    IFS='|' read -r key socket <<<"$entry"
    if ! "${SUDO[@]}" test -S "$socket"; then
      print_service_diagnostics
      die "rota $key não ficou disponível após ${timeout_seconds}s: $socket"
    fi

    if command -v stat >/dev/null 2>&1; then
      mode="$("${SUDO[@]}" stat -c '%a' "$socket" 2>/dev/null || true)"
      group="$("${SUDO[@]}" stat -c '%G' "$socket" 2>/dev/null || true)"
      [[ "$mode" == "660" ]] || die "permissão inesperada na rota $key: esperado 0660, encontrado ${mode:-?}"
      [[ "$group" == "$expected_group" ]] || die "grupo inesperado na rota $key: esperado $expected_group, encontrado ${group:-?}"
    fi

    ok "rota disponível: $key -> $socket"
  done
}

validate_client_route_access() {
  local user="$1" group="$2" bin="$3" runtime_dir="$4"
  local runuser_cmd entry key socket
  local -a routes=()

  [[ -n "$user" ]] || return 0
  user_has_registered_group "$user" "$group" || die "usuário $user não está cadastrado no grupo $group."

  runuser_cmd="$(resolve_system_command runuser)" || {
    die "runuser não encontrado. No Debian, ele é fornecido pelo pacote util-linux."
  }

  mapfile -t routes < <(discover_route_sockets "$bin" "$runtime_dir")
  [[ ${#routes[@]} -gt 0 ]] || die "nenhuma rota pública foi encontrada para validar o usuário cliente."

  "${SUDO[@]}" "$runuser_cmd" -u "$user" -- test -x "$runtime_dir" || {
    die "usuário $user não consegue atravessar o runtime $runtime_dir."
  }
  "${SUDO[@]}" "$runuser_cmd" -u "$user" -- test -x "$runtime_dir/routes" || {
    die "usuário $user não consegue atravessar $runtime_dir/routes."
  }

  for entry in "${routes[@]}"; do
    IFS='|' read -r key socket <<<"$entry"
    "${SUDO[@]}" "$runuser_cmd" -u "$user" -- test -w "$socket" || {
      die "usuário $user não possui permissão para consumir a rota $key: $socket"
    }
    ok "acesso do cliente validado: $user -> $key ($socket)"
  done
}
start_or_restart_service() {
  local bin="$1" runtime_dir="$2" expected_group="$3"

  if "${SUDO[@]}" systemctl is-active --quiet "$APP_NAME"; then
    info "serviço já está ativo; reiniciando para carregar o binário instalado..."
    if ! "${SUDO[@]}" systemctl restart "$APP_NAME"; then
      print_service_diagnostics
      die "falha ao reiniciar $APP_NAME."
    fi
  else
    info "iniciando serviço $APP_NAME..."
    if ! "${SUDO[@]}" systemctl start "$APP_NAME"; then
      print_service_diagnostics
      die "falha ao iniciar $APP_NAME."
    fi
  fi

  validate_published_routes "$bin" "$runtime_dir" "$expected_group" 180
  ok "serviço ativo e rotas públicas disponíveis."
}
print_summary() {
  cat <<__SUMMARY__

============================================================
Resumo da instalação
============================================================
Binário de origem : $BIN_SOURCE
Binário instalado : $BIN_TARGET
Configuração       : $CONFIG_DIR
Estado persistente : $STATE_DIR
Runtime            : $RUNTIME_DIR
llama.cpp versão   : $LLAMA_CPP_VERSION
llama-server modo  : ${LLAMA_INSTALLATION_MODE:-unknown}
llama-server origem: $LLAMA_SOURCE
llama-server alvo  : $LLAMA_TARGET
Modelo GGUF modo   : ${MODEL_INSTALLATION_MODE:-unknown}
Modelo GGUF origem : $MODEL_SOURCE
Modelo GGUF alvo   : $MODEL_TARGET
Usuário de serviço : $SERVICE_USER
Grupo de serviço   : $SERVICE_GROUP
Usuário cliente    : ${CLIENT_USER:-nenhum}
Criar conta serviço: $CREATE_SERVICE_ACCOUNT
Instalar systemd   : $INSTALL_SYSTEMD
Subir serviço agora: ${START_SERVICE:-no}
Habilitar no boot  : ${ENABLE_SERVICE:-no}
Config bootstrap    : ${CREATE_BOOTSTRAP_CONFIG:-no}
Unit systemd       : $UNIT_PATH
============================================================
__SUMMARY__
}

parse_arguments() {
  FORCE_MODE=0
  BIN_ARG=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help)
        usage
        exit 0
        ;;
      --force)
        FORCE_MODE=1
        ;;
      --)
        shift
        [[ $# -le 1 ]] || { usage >&2; exit 2; }
        [[ $# -eq 1 ]] && BIN_ARG="$1"
        break
        ;;
      -*)
        die "opção desconhecida: $1"
        ;;
      *)
        [[ -z "$BIN_ARG" ]] || die "apenas um caminho de binário pode ser informado."
        BIN_ARG="$1"
        ;;
    esac
    shift
  done
}

main() {
  parse_arguments "$@"
  require_interactive

  if [[ "$FORCE_MODE" == "1" ]]; then
    info "modo --force ativo: opções padrão serão aplicadas sem perguntas."
  fi

  check_debian_family
  setup_privilege_command
  ensure_debian_packages
  ensure_llama_server_available
  load_existing_unit_defaults

  DEFAULT_BIN_SOURCE="${BIN_ARG:-$(detect_binary_default)}"

  echo
  if [[ "$FORCE_MODE" == "1" ]]; then
    printf '%sConfiguração automática (--force)%s\n' "$C_BOLD" "$C_RESET"
  else
    printf '%sConfiguração interativa%s\n' "$C_BOLD" "$C_RESET"
    echo "Cada parâmetro será confirmado individualmente."
  fi

  BIN_SOURCE="$(ask_value 'Caminho do binário compilado' "$DEFAULT_BIN_SOURCE")"
  [[ -e "$BIN_SOURCE" ]] || die "arquivo não encontrado: $BIN_SOURCE"
  BIN_SOURCE="$(absolute_path "$BIN_SOURCE")"
  confirm_value "Binário de origem" "$BIN_SOURCE"

  BIN_TARGET="$(ask_absolute_path 'Destino do executável' "$DEFAULT_BIN_TARGET" 'Destino do executável')"
  confirm_value "Destino do executável" "$BIN_TARGET"

  CONFIG_DIR="$(ask_absolute_path 'Diretório de configuração' "$DEFAULT_CONFIG_DIR" 'Diretório de configuração')"
  confirm_value "Diretório de configuração" "$CONFIG_DIR"

  STATE_DIR="$(ask_absolute_path 'Diretório de estado persistente' "$DEFAULT_STATE_DIR" 'Diretório de estado')"
  confirm_value "Diretório de estado" "$STATE_DIR"

  RUNTIME_DIR="$(ask_absolute_path 'Diretório de runtime' "$DEFAULT_RUNTIME_DIR" 'Diretório de runtime')"
  confirm_value "Diretório de runtime" "$RUNTIME_DIR"

  LLAMA_SOURCE="$(ask_llama_source "$LLAMA_SOURCE")"
  LLAMA_SOURCE="$(absolute_path "$LLAMA_SOURCE")"
  confirm_value "llama-server detectado" "$LLAMA_SOURCE"

  LLAMA_TARGET="$(ask_absolute_path 'Destino controlado do llama-server' "$DEFAULT_LLAMA_TARGET" 'Destino do llama-server')"
  confirm_value "Destino do llama-server" "$LLAMA_TARGET"

  select_or_download_model "$STATE_DIR"
  MODEL_SOURCE="$(absolute_path "$MODEL_SOURCE")"
  confirm_value "Modelo GGUF selecionado" "$MODEL_SOURCE"

  MODEL_TARGET="$STATE_DIR/models/$(basename -- "$MODEL_SOURCE")"
  confirm_value "Destino controlado do modelo GGUF" "$MODEL_TARGET"

  SERVICE_USER="$(ask_value 'Usuário de serviço' "$DEFAULT_SERVICE_USER")"
  confirm_value "Usuário de serviço" "$SERVICE_USER"

  SERVICE_GROUP="$(ask_value 'Grupo de serviço' "$DEFAULT_SERVICE_GROUP")"
  confirm_value "Grupo de serviço" "$SERVICE_GROUP"

  if ask_yes_no "Criar/usar usuário e grupo de serviço dedicados?" "Y"; then
    CREATE_SERVICE_ACCOUNT="yes"
  else
    CREATE_SERVICE_ACCOUNT="no"
  fi
  confirm_value "Criar conta de serviço" "$CREATE_SERVICE_ACCOUNT"

  DEFAULT_CLIENT_USER="$(detect_client_user)"
  CLIENT_USER="$(ask_value 'Usuário cliente autorizado a consumir os sockets (vazio = nenhum)' "$DEFAULT_CLIENT_USER")"
  if [[ -n "$CLIENT_USER" ]]; then
    confirm_value "Usuário cliente" "$CLIENT_USER"
  else
    info "nenhum usuário cliente será adicionado ao grupo do serviço."
  fi

  UNIT_PATH="$(ask_absolute_path 'Caminho da unit systemd' "$DEFAULT_UNIT_PATH" 'Caminho da unit systemd')"
  confirm_value "Unit systemd" "$UNIT_PATH"

  validate_binary "$BIN_SOURCE"

  if supports_daemon_mode "$BIN_SOURCE"; then
    if ask_yes_no "O binário suporta --config. Instalar serviço systemd?" "Y"; then
      INSTALL_SYSTEMD="yes"
    else
      INSTALL_SYSTEMD="no"
    fi
  else
    warn "o binário atual NÃO expõe --config; ele ainda é o bootstrap do projeto."
    warn "um serviço systemd criado agora encerraria imediatamente em vez de atuar como daemon."
    INSTALL_SYSTEMD="no"
    info "systemd será ignorado nesta instalação."
  fi
  confirm_value "Instalar serviço systemd" "$INSTALL_SYSTEMD"

  if [[ "$INSTALL_SYSTEMD" == "yes" && "$CREATE_SERVICE_ACCOUNT" != "yes" ]]; then
    die "a instalação systemd requer usuário/grupo de serviço dedicados."
  fi

  CREATE_BOOTSTRAP_CONFIG="no"
  if [[ "$INSTALL_SYSTEMD" == "yes" ]]; then
    if [[ -e "$CONFIG_DIR/config.yaml" ]]; then
      if grep -Fq '# ai-bash-gen - configuração bootstrap' "$CONFIG_DIR/config.yaml" 2>/dev/null &&
         ! grep -Eq '^[[:space:]]*binary:' "$CONFIG_DIR/config.yaml"; then
        warn "foi detectada uma configuração bootstrap antiga, sem dependências de runtime."
        if ask_yes_no "Substituir a configuração bootstrap antiga pela configuração funcional?" "Y"; then
          CREATE_BOOTSTRAP_CONFIG="replace"
        else
          CREATE_BOOTSTRAP_CONFIG="existing"
        fi
      else
        CREATE_BOOTSTRAP_CONFIG="existing"
      fi
      info "configuração existente: $CONFIG_DIR/config.yaml"
    elif ask_yes_no "config.yaml não existe. Criar configuração funcional?" "Y"; then
      CREATE_BOOTSTRAP_CONFIG="yes"
    else
      die "o serviço requer $CONFIG_DIR/config.yaml."
    fi
    confirm_value "Configuração bootstrap" "$CREATE_BOOTSTRAP_CONFIG"
  fi

  START_SERVICE="no"
  ENABLE_SERVICE="no"
  if [[ "$INSTALL_SYSTEMD" == "yes" ]]; then
    if ask_yes_no "Iniciar/reiniciar o serviço ao final da instalação?" "Y"; then
      START_SERVICE="yes"
    fi
    confirm_value "Subir serviço ao final" "$START_SERVICE"

    if ask_yes_no "Habilitar o serviço para iniciar automaticamente no boot?" "Y"; then
      ENABLE_SERVICE="yes"
    fi
    confirm_value "Habilitar no boot" "$ENABLE_SERVICE"
  fi

  print_summary
  if [[ "$FORCE_MODE" != "1" ]]; then
    ask_yes_no "Executar a instalação com estes parâmetros?" "N" || die "instalação cancelada."
  fi

  if [[ "$CREATE_SERVICE_ACCOUNT" == "yes" ]]; then
    create_service_account "$SERVICE_USER" "$SERVICE_GROUP" "$STATE_DIR"
  fi

  if [[ -n "$CLIENT_USER" ]]; then
    authorize_client_user "$CLIENT_USER" "$SERVICE_GROUP"
  fi

  install_binary "$BIN_SOURCE" "$BIN_TARGET"
  [[ -x "$BIN_TARGET" ]] || die "binário instalado não é executável: $BIN_TARGET"
  INSTALLED_VERSION="$("$BIN_TARGET" --version 2>&1)" || die "binário instalado falhou em --version: $BIN_TARGET"
  [[ "$INSTALLED_VERSION" == ai-bash-gen\ * ]] || die "binário instalado não corresponde ao ai-bash-gen: $INSTALLED_VERSION"
  ok "binário instalado validado: $INSTALLED_VERSION"
  prepare_directories "$CONFIG_DIR" "$STATE_DIR" "$RUNTIME_DIR" "$SERVICE_USER" "$SERVICE_GROUP" "$CREATE_SERVICE_ACCOUNT"

  install_runtime_assets "$LLAMA_SOURCE" "$LLAMA_TARGET" "$MODEL_SOURCE" "$MODEL_TARGET" \
    "$SERVICE_USER" "$SERVICE_GROUP" "$CREATE_SERVICE_ACCOUNT"

  if [[ "$INSTALL_SYSTEMD" == "yes" ]]; then
    [[ "$CREATE_SERVICE_ACCOUNT" == "yes" ]] || die "systemd requer usuário/grupo de serviço dedicados neste instalador."
    if [[ "$CREATE_BOOTSTRAP_CONFIG" == "replace" ]]; then
      "${SUDO[@]}" rm -f -- "$CONFIG_DIR/config.yaml"
      CREATE_BOOTSTRAP_CONFIG="yes"
    fi
    if [[ "$CREATE_BOOTSTRAP_CONFIG" == "yes" ]]; then
      create_bootstrap_config "$CONFIG_DIR" "$SERVICE_GROUP" "$LLAMA_TARGET" "$MODEL_TARGET"
    fi

    validate_runtime_dependencies "$BIN_TARGET" "$CONFIG_DIR/config.yaml" "$SERVICE_USER" "$CREATE_SERVICE_ACCOUNT"

    create_systemd_unit "$UNIT_PATH" "$BIN_TARGET" "$CONFIG_DIR" "$RUNTIME_DIR" "$SERVICE_USER" "$SERVICE_GROUP"

    if [[ "$ENABLE_SERVICE" == "yes" ]]; then
      "${SUDO[@]}" systemctl enable "$APP_NAME"
      ok "serviço habilitado para iniciar no boot."
    fi

    if [[ "$START_SERVICE" == "yes" ]]; then
      start_or_restart_service "$BIN_TARGET" "$RUNTIME_DIR" "$SERVICE_GROUP"
      if [[ -n "$CLIENT_USER" ]]; then
        validate_client_route_access "$CLIENT_USER" "$SERVICE_GROUP" "$BIN_TARGET" "$RUNTIME_DIR"
      fi
    else
      if "${SUDO[@]}" systemctl is-active --quiet "$APP_NAME"; then
        warn "o serviço já estava ativo, mas não foi reiniciado; o processo em memória pode continuar usando o binário anterior."
      else
        warn "o serviço foi instalado, mas não foi iniciado."
      fi
      info "para iniciar/reiniciar depois: sudo systemctl restart $APP_NAME"
    fi
  fi

  echo
  ok "instalação concluída."
  info "teste: $BIN_TARGET --version"
  info "caminhos: $BIN_TARGET --show-paths"
  info "dependências: $BIN_TARGET --config $CONFIG_DIR/config.yaml --check-dependencies"
  info "socket esperado: $RUNTIME_DIR/routes/generate.sock"
  if [[ "${START_SERVICE:-no}" == "yes" ]]; then
    info "serviço e rotas foram validados após a inicialização."
  fi
  if [[ "${CLIENT_SESSION_REFRESH_REQUIRED:-no}" == "yes" ]]; then
    warn "AÇÃO NECESSÁRIA: a sessão atual de $CLIENT_USER ainda não possui o grupo $SERVICE_GROUP."
    warn "execute: newgrp $SERVICE_GROUP  (ou faça logout/login antes de usar o cliente)."
  fi

  if [[ "$INSTALL_SYSTEMD" == "no" ]]; then
    info "nenhum serviço systemd foi instalado."
  fi
}

if [[ "${AI_BASH_GEN_INSTALLER_LIB_ONLY:-0}" != "1" ]]; then
  main "$@"
fi