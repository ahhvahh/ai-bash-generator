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
  ./install-binary.sh --help

Características:
  - exige terminal interativo;
  - confirma cada parâmetro antes da instalação;
  - valida o binário usando --version e --show-paths;
  - instala o executável em /usr/local/bin por padrão;
  - usa /etc, /var/lib e /run conforme o layout definido pelo projeto;
  - cria usuário/grupo de serviço dedicados somente se solicitado;
  - só cria serviço systemd se o binário suportar --config;
  - não altera arquivos do projeto-fonte.
__USAGE__
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-N}"
  local answer suffix

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
  read -r -p "$prompt [$default]: " value
  printf '%s' "${value:-$default}"
}

confirm_value() {
  local label="$1"
  local value="$2"

  printf '\n%s%s%s\n' "$C_BOLD" "$label" "$C_RESET"
  printf '  %s\n' "$value"
  ask_yes_no "Confirmar este valor?" "Y" || die "instalação cancelada pelo usuário."
}

require_interactive() {
  [[ -t 0 && -t 1 ]] || die "este instalador exige um terminal interativo."
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
  local config_dir="$1" group="$2" config_file temp_config
  config_file="$config_dir/config.yaml"

  if [[ -e "$config_file" ]]; then
    info "configuração existente preservada: $config_file"
    return 0
  fi

  temp_config="$(mktemp)"
  cat >"$temp_config" <<'__CONFIG__'
# ai-bash-gen - configuração bootstrap
#
# O daemon atual valida e carrega este arquivo, mas o schema completo
# de configuração ainda será definido conforme a evolução do projeto.
__CONFIG__

  "${SUDO[@]}" install -o root -g "$group" -m 0640 "$temp_config" "$config_file"
  rm -f -- "$temp_config"
  ok "configuração bootstrap criada em $config_file"
}

create_systemd_unit() {
  local unit_path="$1" bin_target="$2" config_dir="$3" user="$4" group="$5"
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
Usuário de serviço : $SERVICE_USER
Grupo de serviço   : $SERVICE_GROUP
Criar conta serviço: $CREATE_SERVICE_ACCOUNT
Instalar systemd   : $INSTALL_SYSTEMD
Config bootstrap    : ${CREATE_BOOTSTRAP_CONFIG:-no}
Unit systemd       : $UNIT_PATH
============================================================
__SUMMARY__
}

main() {
  case "${1:-}" in
    -h|--help|help)
      usage
      exit 0
      ;;
  esac

  require_interactive

  [[ $# -le 1 ]] || { usage >&2; exit 2; }

  check_debian_family
  setup_privilege_command

  DEFAULT_BIN_SOURCE="${1:-$(detect_binary_default)}"

  echo
  printf '%sConfiguração interativa%s\n' "$C_BOLD" "$C_RESET"
  echo "Cada parâmetro será confirmado individualmente."

  BIN_SOURCE="$(ask_value 'Caminho do binário compilado' "$DEFAULT_BIN_SOURCE")"
  [[ -e "$BIN_SOURCE" ]] || die "arquivo não encontrado: $BIN_SOURCE"
  BIN_SOURCE="$(absolute_path "$BIN_SOURCE")"
  confirm_value "Binário de origem" "$BIN_SOURCE"

  BIN_TARGET="$(ask_value 'Destino do executável' "$DEFAULT_BIN_TARGET")"
  confirm_value "Destino do executável" "$BIN_TARGET"

  CONFIG_DIR="$(ask_value 'Diretório de configuração' "$DEFAULT_CONFIG_DIR")"
  confirm_value "Diretório de configuração" "$CONFIG_DIR"

  STATE_DIR="$(ask_value 'Diretório de estado persistente' "$DEFAULT_STATE_DIR")"
  confirm_value "Diretório de estado" "$STATE_DIR"

  RUNTIME_DIR="$(ask_value 'Diretório de runtime' "$DEFAULT_RUNTIME_DIR")"
  confirm_value "Diretório de runtime" "$RUNTIME_DIR"

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

  UNIT_PATH="$(ask_value 'Caminho da unit systemd' "$DEFAULT_UNIT_PATH")"
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
      CREATE_BOOTSTRAP_CONFIG="existing"
      info "configuração existente será utilizada: $CONFIG_DIR/config.yaml"
    elif ask_yes_no "config.yaml não existe. Criar configuração bootstrap?" "Y"; then
      CREATE_BOOTSTRAP_CONFIG="yes"
    else
      die "o serviço requer $CONFIG_DIR/config.yaml."
    fi
    confirm_value "Configuração bootstrap" "$CREATE_BOOTSTRAP_CONFIG"
  fi

  print_summary
  ask_yes_no "Executar a instalação com estes parâmetros?" "N" || die "instalação cancelada."

  if [[ "$CREATE_SERVICE_ACCOUNT" == "yes" ]]; then
    create_service_account "$SERVICE_USER" "$SERVICE_GROUP" "$STATE_DIR"
  fi

  install_binary "$BIN_SOURCE" "$BIN_TARGET"
  prepare_directories "$CONFIG_DIR" "$STATE_DIR" "$RUNTIME_DIR" "$SERVICE_USER" "$SERVICE_GROUP" "$CREATE_SERVICE_ACCOUNT"

  if [[ "$INSTALL_SYSTEMD" == "yes" ]]; then
    [[ "$CREATE_SERVICE_ACCOUNT" == "yes" ]] || die "systemd requer usuário/grupo de serviço dedicados neste instalador."
    if [[ "$CREATE_BOOTSTRAP_CONFIG" == "yes" ]]; then
      create_bootstrap_config "$CONFIG_DIR" "$SERVICE_GROUP"
    fi

    create_systemd_unit "$UNIT_PATH" "$BIN_TARGET" "$CONFIG_DIR" "$SERVICE_USER" "$SERVICE_GROUP"

    warn "o serviço não será habilitado nem iniciado automaticamente."
    info "revise primeiro: $CONFIG_DIR/config.yaml"
    info "depois execute, se apropriado: sudo systemctl enable --now $APP_NAME"
  fi

  echo
  ok "instalação concluída."
  info "teste: $BIN_TARGET --version"
  info "caminhos: $BIN_TARGET --show-paths"

  if [[ "$INSTALL_SYSTEMD" == "no" ]]; then
    info "nenhum serviço systemd foi instalado."
  fi
}

main "$@"