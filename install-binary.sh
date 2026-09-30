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

REQUIRED_DEBIAN_PACKAGES=(bash coreutils grep mawk passwd util-linux libc-bin systemd file binutils)

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
  - valida o binário usando --version e --show-paths, incluindo generate_socket;
  - instala o executável em /usr/local/bin por padrão;
  - usa /etc, /var/lib e /run conforme o layout definido pelo projeto;
  - cria usuário/grupo de serviço dedicados somente se solicitado;
  - só cria serviço systemd se o binário suportar --config;
  - verifica dependências Debian e oferece instalar pacotes ausentes;
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
package_installed() {
  local package="$1"
  command -v dpkg-query >/dev/null 2>&1 || return 1
  dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fxq 'install ok installed'
}

ensure_debian_packages() {
  local package
  local -a missing=()

  if ! command -v dpkg-query >/dev/null 2>&1; then
    warn "dpkg-query não encontrado; validação de pacotes Debian será ignorada."
    return 0
  fi

  for package in "${REQUIRED_DEBIAN_PACKAGES[@]}"; do
    package_installed "$package" || missing+=("$package")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "dependências Debian instaladas: ${REQUIRED_DEBIAN_PACKAGES[*]}"
    return 0
  fi

  warn "pacotes Debian ausentes: ${missing[*]}"
  command -v apt-get >/dev/null 2>&1 || die "apt-get não encontrado; instale manualmente: ${missing[*]}"

  ask_yes_no "Instalar os pacotes ausentes agora?" "Y" || {
    die "dependências obrigatórias ausentes: ${missing[*]}"
  }

  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" apt-get install -y -- "${missing[@]}"
  ok "dependências Debian instaladas."
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
  local target_uid group_gid pid proc_uid proc_gid proc_ppid groups_line

  target_uid="$(id -u "$user" 2>/dev/null)" || return 2
  group_gid="$(getent group "$group" 2>/dev/null | awk -F: '{print $3; exit}')"
  [[ -n "$group_gid" ]] || return 2

  pid="$(awk '/^Tgid:/ {print $2; exit}' /proc/self/status 2>/dev/null || true)"
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
  fi

  rc=$?
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

  validate_published_routes "$bin" "$runtime_dir" "$expected_group" 10
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
  ensure_debian_packages
  load_existing_unit_defaults

  DEFAULT_BIN_SOURCE="${1:-$(detect_binary_default)}"

  echo
  printf '%sConfiguração interativa%s\n' "$C_BOLD" "$C_RESET"
  echo "Cada parâmetro será confirmado individualmente."

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
      CREATE_BOOTSTRAP_CONFIG="existing"
      info "configuração existente será utilizada: $CONFIG_DIR/config.yaml"
    elif ask_yes_no "config.yaml não existe. Criar configuração bootstrap?" "Y"; then
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
  ask_yes_no "Executar a instalação com estes parâmetros?" "N" || die "instalação cancelada."

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

  if [[ "$INSTALL_SYSTEMD" == "yes" ]]; then
    [[ "$CREATE_SERVICE_ACCOUNT" == "yes" ]] || die "systemd requer usuário/grupo de serviço dedicados neste instalador."
    if [[ "$CREATE_BOOTSTRAP_CONFIG" == "yes" ]]; then
      create_bootstrap_config "$CONFIG_DIR" "$SERVICE_GROUP"
    fi

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