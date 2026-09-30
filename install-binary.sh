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

CaracterÃ­sticas:
  - exige terminal interativo;
  - confirma cada parÃ¢metro antes da instalaÃ§Ã£o;
  - valida o binÃ¡rio usando --version e --show-paths;
  - instala o executÃ¡vel em /usr/local/bin por padrÃ£o;
  - usa /etc, /var/lib e /run conforme o layout definido pelo projeto;
  - cria usuÃ¡rio/grupo de serviÃ§o dedicados somente se solicitado;
  - sÃ³ cria serviÃ§o systemd se o binÃ¡rio suportar --config;
  - nÃ£o altera arquivos do projeto-fonte.
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
      n|N|nao|Nao|NAO|nÃ£o|NÃ£o|NÃƒO|no|No|NO) return 1 ;;
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
  ask_yes_no "Confirmar este valor?" "Y" || die "instalaÃ§Ã£o cancelada pelo usuÃ¡rio."
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
    warn "o sistema nÃ£o foi identificado como Debian ou derivado."
    ask_yes_no "Continuar mesmo assim?" "N" || die "instalaÃ§Ã£o cancelada."
  fi
}

setup_privilege_command() {
  if [[ "$EUID" -eq 0 ]]; then
    SUDO=()
    info "execuÃ§Ã£o como root; sudo nÃ£o serÃ¡ usado."
    return
  fi

  command -v sudo >/dev/null 2>&1 || die "sudo nÃ£o encontrado. Execute como root ou instale/configure sudo."
  SUDO=(sudo)
  info "operaÃ§Ãµes administrativas usarÃ£o sudo."
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

  [[ -f "$bin" ]] || die "binÃ¡rio nÃ£o encontrado: $bin"
  [[ -s "$bin" ]] || die "binÃ¡rio vazio: $bin"

  if [[ ! -x "$bin" ]]; then
    warn "o binÃ¡rio nÃ£o possui permissÃ£o de execuÃ§Ã£o."
    ask_yes_no "Aplicar chmod +x no binÃ¡rio de origem?" "Y" || die "binÃ¡rio nÃ£o executÃ¡vel."
    chmod +x -- "$bin"
  fi

  if command -v file >/dev/null 2>&1; then
    file_output="$(file -b -- "$bin")"
    info "arquivo: $file_output"
    grep -qi 'ELF' <<<"$file_output" || warn "o arquivo nÃ£o foi identificado como ELF Linux."
  fi

  version_output="$("$bin" --version 2>&1)" || die "falha ao executar '$bin --version'."
  [[ "$version_output" == ai-bash-gen\ * ]] || die "o arquivo nÃ£o parece ser o ai-bash-gen: $version_output"
  info "versÃ£o detectada: $version_output"

  paths_output="$("$bin" --show-paths 2>&1)" || die "falha ao executar '$bin --show-paths'."

  grep -Fxq "config_dir=$DEFAULT_CONFIG_DIR" <<<"$paths_output" || die "config_dir do binÃ¡rio nÃ£o corresponde a $DEFAULT_CONFIG_DIR"
  grep -Fxq "state_dir=$DEFAULT_STATE_DIR" <<<"$paths_output" || die "state_dir do binÃ¡rio nÃ£o corresponde a $DEFAULT_STATE_DIR"
  grep -Fxq "runtime_dir=$DEFAULT_RUNTIME_DIR" <<<"$paths_output" || die "runtime_dir do binÃ¡rio nÃ£o corresponde a $DEFAULT_RUNTIME_DIR"
  grep -Fxq "routes_dir=$DEFAULT_RUNTIME_DIR/routes" <<<"$paths_output" || die "routes_dir do binÃ¡rio nÃ£o corresponde ao layout esperado"
  grep -Fxq "llama_socket=$DEFAULT_RUNTIME_DIR/internal/llama.sock" <<<"$paths_output" || die "llama_socket do binÃ¡rio nÃ£o corresponde ao layout esperado"

  ok "binÃ¡rio validado."
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
  # Resolva os caminhos antes de qualquer alteraÃ§Ã£o para nÃ£o depender do PATH.
  groupadd_cmd="$(resolve_system_command groupadd)" || {
    die "groupadd nÃ£o encontrado. No Debian, ele Ã© fornecido pelo pacote 'passwd'. Instale com: sudo apt install passwd"
  }

  useradd_cmd="$(resolve_system_command useradd)" || {
    die "useradd nÃ£o encontrado. No Debian, ele Ã© fornecido pelo pacote 'passwd'. Instale com: sudo apt install passwd"
  }

  if nologin_shell="$(resolve_system_command nologin 2>/dev/null)"; then
    :
  elif [[ -x /usr/sbin/nologin ]]; then
    nologin_shell="/usr/sbin/nologin"
  else
    die "shell nologin nÃ£o encontrada em um caminho padrÃ£o Debian."
  fi

  info "groupadd: $groupadd_cmd"
  info "useradd:  $useradd_cmd"

  if getent group "$group" >/dev/null 2>&1; then
    info "grupo jÃ¡ existe: $group"
  else
    "${SUDO[@]}" "$groupadd_cmd" --system "$group"
    ok "grupo criado: $group"
  fi

  if id "$user" >/dev/null 2>&1; then
    info "usuÃ¡rio jÃ¡ existe: $user"
  else
    "${SUDO[@]}" "$useradd_cmd" \
      --system \
      --gid "$group" \
      --home-dir "$home" \
      --no-create-home \
      --shell "$nologin_shell" \
      "$user"
    ok "usuÃ¡rio criado: $user"
  fi
}

install_binary() {
  local source="$1" target="$2"
  local target_dir backup

  target_dir="$(dirname -- "$target")"
  "${SUDO[@]}" install -d -o root -g root -m 0755 "$target_dir"

  if [[ -e "$target" ]]; then
    warn "jÃ¡ existe um binÃ¡rio instalado em: $target"
    if command -v sha256sum >/dev/null 2>&1; then
      info "SHA-256 atual: $(sha256sum -- "$target" 2>/dev/null | awk '{print $1}' || true)"
      info "SHA-256 novo : $(sha256sum -- "$source" | awk '{print $1}')"
    fi

    ask_yes_no "Substituir o binÃ¡rio existente?" "N" || die "instalaÃ§Ã£o cancelada."

    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    "${SUDO[@]}" cp -a -- "$target" "$backup"
    info "backup criado: $backup"
  fi

  "${SUDO[@]}" install -o root -g root -m 0755 -- "$source" "$target"
  ok "binÃ¡rio instalado em $target"
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

  ok "diretÃ³rios preparados."
}

create_bootstrap_config() {
  local config_dir="$1" group="$2" config_file temp_config
  config_file="$config_dir/config.yaml"

  if [[ -e "$config_file" ]]; then
    info "configuraÃ§Ã£o existente preservada: $config_file"
    return 0
  fi

  temp_config="$(mktemp)"
  cat >"$temp_config" <<'__CONFIG__'
# ai-bash-gen - configuraÃ§Ã£o bootstrap
#
# O daemon atual valida e carrega este arquivo, mas o schema completo
# de configuraÃ§Ã£o ainda serÃ¡ definido conforme a evoluÃ§Ã£o do projeto.
__CONFIG__

  "${SUDO[@]}" install -o root -g "$group" -m 0640 "$temp_config" "$config_file"
  rm -f -- "$temp_config"
  ok "configuraÃ§Ã£o bootstrap criada em $config_file"
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
Resumo da instalaÃ§Ã£o
============================================================
BinÃ¡rio de origem : $BIN_SOURCE
BinÃ¡rio instalado : $BIN_TARGETø)½¹™¥ÕÉ‡Ÿ¼€€€€€€€è€‘=9%}%H)ÍÑ…‘¼Á•ÉÍ¥ÍÑ•¹Ñ”€è€‘MQQ}%H)IÕ¹Ñ¥µ”€€€€€€€€€€€€è€‘IU9Q%5}%H)UÍ×…É¥¼‘”Í•ÉÙ§¼€è€‘MIY%}UMH)ÉÕÁ¼‘”Í•ÉÙ§¼€€€è€‘MIY%}I=U@)É¥…È½¹Ñ„Í•ÉÙ§¼è€‘IQ}MIY%}=U9P)%¹ÍÑ…±…ÈÍåÍÑ•µ€€€è€‘%9MQ11}MeMQ5)½¹™¥œ‰½½ÑÍÑÉ…À€€€€è€‘íIQ}	==QMQIA}=9%èµ¹½ô)U¹¥ÐÍåÍÑ•µ€€€€€€€è€‘U9%Q}AQ (ôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôôô)}}MU55Ie}|)ô()µ…¥¸ ¤ì(€…Í”€ˆ‘ìÄèµôˆ¥¸(€€€€µ¡ð´µ¡•±Áñ¡•±À¤(€€€€€ÕÍ…”(€€€€€•á¥Ð€À(€€€€€€ìì(€•Í…Œ((€É•ÅÕ¥É•}¥¹Ñ•É…Ñ¥Ù”((€ml€Œ€µ±”€ÄutñðìÕÍ…”€ø˜Èì•á¥Ð€Èìô((€¡•­}‘•‰¥…¹}™…µ¥±ä(€Í•ÑÕÁ}ÁÉ¥Ù¥±••}½µµ…¹((€U1Q}	%9}M=UIôˆ‘ìÄè´¡‘•Ñ•Ñ}‰¥¹…Éå}‘•™…Õ±Ð¥ôˆ((€•¡¼(€ÁÉ¥¹Ñ˜€œ•Í½¹™¥ÕÉ‡Ÿ¼¥¹Ñ•É…Ñ¥Ù„•Íq¸œ€ˆ‘}	=1ˆ€ˆ‘}IMPˆ(€•¡¼€‰…‘„Á…Ë‰µ•ÑÉ¼Í•Ë„½¹™¥Éµ…‘¼¥¹‘¥Ù¥‘Õ…±µ•¹Ñ”¸ˆ((€	%9}M=UIôˆ¡…Í­}Ù…±Õ”€…µ¥¹¡¼‘¼‰¥»…É¥¼½µÁ¥±…‘¼œ€ˆ‘U1Q}	%9}M=UIˆ¤ˆ(€ml€µ”€ˆ‘	%9}M=UIˆutñð‘¥”€‰…ÉÅÕ¥Ù¼»¼•¹½¹ÑÉ…‘¼è€‘	%9}M=UIˆ(€	%9}M=UIôˆ¡…‰Í½±ÕÑ•}Á…Ñ €ˆ‘	%9}M=UIˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰	¥»…É¥¼‘”½É¥•´ˆ€ˆ‘	%9}M=UIˆ((€	%9}QIPôˆ¡…Í­}Ù…±Õ”€•ÍÑ¥¹¼‘¼•á•ÕÓ…Ù•°œ€ˆ‘U1Q}	%9}QIPˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰•ÍÑ¥¹¼‘¼•á•ÕÓ…Ù•°ˆ€ˆ‘	%9}QIPˆ((€=9%}%Hôˆ¡…Í­}Ù…±Õ”€¥É•ÓÍÉ¥¼‘”½¹™¥ÕÉ‡Ÿ¼œ€ˆ‘U1Q}=9%}%Hˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰¥É•ÓÍÉ¥¼‘”½¹™¥ÕÉ‡Ÿ¼ˆ€ˆ‘=9%}%Hˆ((€MQQ}%Hôˆ¡…Í­}Ù…±Õ”€¥É•ÓÍÉ¥¼‘”•ÍÑ…‘¼Á•ÉÍ¥ÍÑ•¹Ñ”œ€ˆ‘U1Q}MQQ}%Hˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰¥É•ÓÍÉ¥¼‘”•ÍÑ…‘¼ˆ€ˆ‘MQQ}%Hˆ((€IU9Q%5}%Hôˆ¡…Í­}Ù…±Õ”€¥É•ÓÍÉ¥¼‘”ÉÕ¹Ñ¥µ”œ€ˆ‘U1Q}IU9Q%5}%Hˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰¥É•ÓÍÉ¥¼‘”ÉÕ¹Ñ¥µ”ˆ€ˆ‘IU9Q%5}%Hˆ((€MIY%}UMHôˆ¡…Í­}Ù…±Õ”€UÍ×…É¥¼‘”Í•ÉÙ§¼œ€ˆ‘U1Q}MIY%}UMHˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰UÍ×…É¥¼‘”Í•ÉÙ§¼ˆ€ˆ‘MIY%}UMHˆ((€MIY%}I=U@ôˆ¡…Í­}Ù…±Õ”€ÉÕÁ¼‘”Í•ÉÙ§¼œ€ˆ‘U1Q}MIY%}I=U@ˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰ÉÕÁ¼‘”Í•ÉÙ§¼ˆ€ˆ‘MIY%}I=U@ˆ(€¥˜…Í­}å•Í}¹¼€‰É¥…È½ÕÍ…ÈÕÍ×…É¥¼”ÉÕÁ¼‘”Í•ÉÙ§¼‘•‘¥…‘½Ìüˆ€‰dˆìÑ¡•¸(€€€IQ}MIY%}=U9Pô‰å•Ìˆ(€•±Í”(€€€IQ}MIY%}=U9Pô‰¹¼ˆ(€™¤(€½¹™¥Éµ}Ù…±Õ”€‰É¥…È½¹Ñ„‘”Í•ÉÙ§¼ˆ€ˆ‘IQ}MIY%}=U9Pˆ((€U9%Q}AQ ôˆ¡…Í­}Ù…±Õ”€…µ¥¹¡¼‘„Õ¹¥ÐÍåÍÑ•µœ€ˆ‘U1Q}U9%Q}AQ ˆ¤ˆ(€½¹™¥Éµ}Ù…±Õ”€‰U¹¥ÐÍåÍÑ•µˆ€ˆ‘U9%Q}AQ ˆ((€Ù…±¥‘…Ñ•}‰¥¹…Éä€ˆ‘	%9}M=UIˆ((€¥˜ÍÕÁÁ½ÉÑÍ}‘…•µ½¹}µ½‘”€ˆ‘	%9}M=UIˆìÑ¡•¸(€€€¥˜…Í­}å•Í}¹¼€‰<‰¥»…É¥¼ÍÕÁ½ÉÑ„€´µ½¹™¥œ¸%¹ÍÑ…±…ÈÍ•ÉÙ§¼ÍåÍÑ•µüˆ€‰dˆìÑ¡•¸(€€€€€%9MQ11}MeMQ5ô‰å•Ìˆ(€€€•±Í”(€€€€€%9MQ11}MeMQ5ô‰¹¼ˆ(€€€™¤(€•±Í”(€€€Ý…É¸€‰¼‰¥»…É¥¼…ÑÕ…°;<•áÃÕ”€´µ½¹™¥œì•±”…¥¹‘„ƒ¤¼‰½½ÑÍÑÉ…À‘¼ÁÉ½©•Ñ¼¸ˆ(€€€Ý…É¸€‰Õ´Í•ÉÙ§¼ÍåÍÑ•µÉ¥…‘¼…½É„•¹•ÉÉ…É¥„¥µ•‘¥…Ñ…µ•¹Ñ”•´Ù•è‘”…ÑÕ…È½µ¼‘…•µ½¸¸ˆ(€€€%9MQ11}MeMQ5ô‰¹¼ˆ(€€€¥¹™¼€‰ÍåÍÑ•µÍ•Ë„¥¹½É…‘¼¹•ÍÑ„¥¹ÍÑ…±‡Ÿ¼¸ˆ(€™¤(€½¹™¥Éµ}Ù…±Õ”€‰%¹ÍÑ…±…ÈÍ•ÉÙ§¼ÍåÍÑ•µˆ€ˆ‘%9MQ11}MeMQ5ˆ((€¥˜ml€ˆ‘%9MQ11}MeMQ5ˆ€ôô€‰å•Ìˆ€˜˜€ˆ‘IQ}MIY%}=U9Pˆ€„ô€‰å•ÌˆutìÑ¡•¸(€€€‘¥”€‰„¥¹ÍÑ…±‡Ÿ¼ÍåÍÑ•µÉ•ÅÕ•ÈÕÍ×…É¥¼½ÉÕÁ¼‘”Í•ÉÙ§¼‘•‘¥…‘½Ì¸ˆ(€™¤((€IQ}	==QMQIA}=9%ô‰¹¼ˆ(€¥˜ml€ˆ‘%9MQ11}MeMQ5ˆ€ôô€‰å•ÌˆutìÑ¡•¸(€€€¥˜ml€µ”€ˆ‘=9%}%H½½¹™¥œ¹å…µ°ˆutìÑ¡•¸(€€€€€IQ}	==QMQIA}=9%ô‰•á¥ÍÑ¥¹œˆ(€€€€€¥¹™¼€‰½¹™¥ÕÉ‡Ÿ¼•á¥ÍÑ•¹Ñ”Í•Ë„ÕÑ¥±¥é…‘„è€‘=9%}%H½½¹™¥œ¹å…µ°ˆ(€€€•±¥˜…Í­}å•Í}¹¼€‰½¹™¥œ¹å…µ°»¼•á¥ÍÑ”¸É¥…È½¹™¥ÕÉ‡Ÿ¼‰½½ÑÍÑÉ…Àüˆ€‰dˆìÑ¡•¸(€€€€€IQ}	==QMQIA}=9%ô‰å•Ìˆ(€€€•±Í”(€€€€€‘¥”€‰¼Í•ÉÙ§¼É•ÅÕ•È€‘=9%}%H½½¹™¥œ¹å…µ°¸ˆ(€€€™¤(€€€½¹™¥Éµ}Ù…±Õ”€‰½¹™¥ÕÉ‡Ÿ¼‰½½ÑÍÑÉ…Àˆ€ˆ‘IQ}	==QMQIA}=9%ˆ(€™¤((€ÁÉ¥¹Ñ}ÍÕµµ…Éä(€…Í­}å•Í}¹¼€‰á•ÕÑ…È„¥¹ÍÑ…±‡Ÿ¼½´•ÍÑ•ÌÁ…Ë‰µ•ÑÉ½Ìüˆ€‰8ˆñð‘¥”€‰¥¹ÍÑ…±‡Ÿ¼…¹•±…‘„¸ˆ((€¥˜ml€ˆ‘IQ}MIY%}=U9Pˆ€ôô€‰å•ÌˆutìÑ¡•¸(€€€É•…Ñ•}Í•ÉÙ¥•}…½Õ¹Ð€ˆ‘MIY%}UMHˆ€ˆ‘MIY%}I=U@ˆ€ˆ‘MQQ}%Hˆ(€™¤((€¥¹ÍÑ…±±}‰¥¹…Éä€ˆ‘	%9}M=UIˆ€ˆ‘	%9}QIPˆ(€ÁÉ•Á…É•}‘¥É•Ñ½É¥•Ì€ˆ‘=9%}%Hˆ€ˆ‘MQQ}%Hˆ€ˆ‘IU9Q%5}%Hˆ€ˆ‘MIY%}UMHˆ€ˆ‘MIY%}I=U@ˆ€ˆ‘IQ}MIY%}=U9Pˆ((€¥˜ml€ˆ‘%9MQ11}MeMQ5ˆ€ôô€‰å•ÌˆutìÑ¡•¸(€€€ml€ˆ‘IQ}MIY%}=U9Pˆ€ôô€‰å•Ìˆutñð‘¥”€‰ÍåÍÑ•µÉ•ÅÕ•ÈÕÍ×…É¥¼½ÉÕÁ¼‘”Í•ÉÙ§¼‘•‘¥…‘½Ì¹•ÍÑ”¥¹ÍÑ…±…‘½È¸ˆ(€€€¥˜ml€ˆ‘IQ}	==QMQIA}=9%ˆ€ôô€‰å•ÌˆutìÑ¡•¸(€€€€€É•…Ñ•}‰½½ÑÍÑÉ…Á}½¹™¥œ€ˆ‘=9%}%Hˆ€ˆ‘MIY%}I=U@ˆ(€€€™¤((€€€É•…Ñ•}ÍåÍÑ•µ‘}Õ¹¥Ð€ˆ‘U9%Q}AQ ˆ€ˆ‘	%9}QIPˆ€ˆ‘=9%}%Hˆ€ˆ‘MIY%}UMHˆ€ˆ‘MIY%}I=U@ˆ((€€€Ý…É¸€‰¼Í•ÉÙ§¼»¼Í•Ë„¡…‰¥±¥Ñ…‘¼¹•´¥¹¥¥…‘¼…ÕÑ½µ…Ñ¥…µ•¹Ñ”¸ˆ(€€€¥¹™¼€‰É•Ù¥Í”ÁÉ¥µ•¥É¼è€‘=9%}%H½½¹™¥œ¹å…µ°ˆ(€€€¥¹™¼€‰‘•Á½¥Ì•á•ÕÑ”°Í”…ÁÉ½ÁÉ¥…‘¼èÍÕ‘¼ÍåÍÑ•µÑ°•¹…‰±”€´µ¹½Ü€‘AA}95ˆ(€™¤((€•¡¼(€½¬€‰¥¹ÍÑ…±‡Ÿ¼½¹±×µ‘„¸ˆ(€¥¹™¼€‰Ñ•ÍÑ”è€‘	%9}QIP€´µÙ•ÉÍ¥½¸ˆ(€¥¹™¼€‰…µ¥¹¡½Ìè€‘	%9}QIP€´µÍ¡½ÜµÁ…Ñ¡Ìˆ((€¥˜ml€ˆ‘%9MQ11}MeMQ5ˆ€ôô€‰¹¼ˆutìÑ¡•¸(€€€¥¹™¼€‰¹•¹¡Õ´Í•ÉÙ§¼ÍåÍÑ•µ™½¤¥¹ÍÑ…±…‘¼¸ˆ(€™¤)ô()µ…¥¸€ˆ‘ ˆ(