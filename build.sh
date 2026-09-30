#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_ROOT="$ROOT/src"
GO_ROOT="$SRC_ROOT/go"
BIN="$ROOT/bin"
PROJECT_NAME="ai-bash-gen"
SOURCE_PACKAGE="./cmd/ai-bash-gen"
MODULE_PATH="github.com/ahhvahh/ai-bash-generator"

SUPPORTED_ARCHITECTURES=(
  amd64
  386
  arm64
  arm
  riscv64
  mips64
  mips
  ppc64
  ppc64le
  s390x
)

usage() {
  cat <<'TXT'
Uso:
  ./build.sh <arquitetura>
  ./build.sh --versions
  ./build.sh --list-targets
  ./build.sh clean
  ./build.sh --help

Arquiteturas suportadas:
  amd64
  386
  arm64
  arm
  riscv64
  mips64
  mips
  ppc64
  ppc64le
  s390x

O build gera somente em:
  bin/<arquitetura>/ai-bash-gen

Sem argumento o build é recusado.
TXT
}

list_targets() {
  local arch toolchain

  for arch in "${SUPPORTED_ARCHITECTURES[@]}"; do
    toolchain="linux/$arch"
    if [[ "$arch" == "arm" ]]; then
      toolchain="linux/arm GOARM=7"
    fi

    printf 'TARGET|%s|ready|bin/%s/%s|%s\n' \
      "$arch" "$arch" "$PROJECT_NAME" "$toolchain"
  done
}

show_versions() {
  cat <<EOF
$PROJECT_NAME - targets suportados

Código-fonte: src/go
Entrypoint:  src/go/cmd/ai-bash-gen

Targets:
EOF

  list_targets

  cat <<'EOF'
TARGET|riscv32|unsupported|-|-
TARGET|xtensa|unsupported|-|-

Toolchain:
EOF

  if command -v go >/dev/null 2>&1; then
    printf '  Go: '
    go version
  else
    echo '  Go: não instalado'
  fi
}

clean_bin() {
  rm -rf -- "$BIN"
  mkdir -p -- "$BIN"
}

cleanup_on_exit() {
  local rc=$?
  trap - EXIT

  if [[ $rc -ne 0 ]]; then
    rm -rf -- "$BIN"
    mkdir -p -- "$BIN"
  fi

  exit "$rc"
}

require_go() {
  command -v go >/dev/null 2>&1 || {
    echo '[ERRO] Go não encontrado no PATH.' >&2
    exit 1
  }

  if [[ ! -f "$GO_ROOT/go.mod" ]]; then
    echo "[ERRO] go.mod não encontrado em: $GO_ROOT" >&2
    exit 1
  fi
}

run_tests() {
  echo '[tests] go test ./...'
  (
    cd "$GO_ROOT"
    go test ./...
  )
}

build_go() {
  local arch="$1"
  local output_dir="$BIN/$arch"
  local output_file="$output_dir/$PROJECT_NAME"
  local commit version ldflags

  mkdir -p -- "$output_dir"

  commit="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  version="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || printf 'dev')"

  ldflags="-s -w -X ${MODULE_PATH}/internal/buildinfo.Version=${version} -X ${MODULE_PATH}/internal/buildinfo.Commit=${commit}"

  echo "[build] linux/$arch -> ${output_file#$ROOT/}"

  case "$arch" in
    arm)
      (
        cd "$GO_ROOT"
        CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 \
          go build -trimpath -ldflags "$ldflags" -o "$output_file" "$SOURCE_PACKAGE"
      )
      ;;
    amd64)
      (
        cd "$GO_ROOT"
        CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOAMD64=v1 \
          go build -trimpath -ldflags "$ldflags" -o "$output_file" "$SOURCE_PACKAGE"
      )
      ;;
    *)
      (
        cd "$GO_ROOT"
        CGO_ENABLED=0 GOOS=linux GOARCH="$arch" \
          go build -trimpath -ldflags "$ldflags" -o "$output_file" "$SOURCE_PACKAGE"
      )
      ;;
  esac
}

is_supported_architecture() {
  local candidate="$1"
  local arch

  for arch in "${SUPPORTED_ARCHITECTURES[@]}"; do
    [[ "$candidate" == "$arch" ]] && return 0
  done

  return 1
}

[[ $# -gt 0 ]] || {
  echo '[ERRO] informe explicitamente uma arquitetura de compilação.' >&2
  usage >&2
  exit 2
}

TARGET="$1"
shift

[[ $# -eq 0 ]] || {
  echo '[ERRO] argumentos adicionais não são suportados.' >&2
  exit 2
}

case "$TARGET" in
  -h|--help|help)
    usage
    exit 0
    ;;
  --versions|versions)
    show_versions
    exit 0
    ;;
  --list-targets)
    list_targets
    exit 0
    ;;
  clean)
    clean_bin
    echo '[OK] bin/ limpo.'
    exit 0
    ;;
esac

if ! is_supported_architecture "$TARGET"; then
  echo "[ERRO] arquitetura não suportada: $TARGET" >&2
  usage >&2
  exit 2
fi

require_go
clean_bin
trap cleanup_on_exit EXIT

run_tests
build_go "$TARGET"

if [[ ! -s "$BIN/$TARGET/$PROJECT_NAME" ]]; then
  echo "[ERRO] artefato não foi gerado: $BIN/$TARGET/$PROJECT_NAME" >&2
  exit 1
fi

trap - EXIT
echo '[OK] build concluído.'
find "$BIN/$TARGET" -mindepth 1 -maxdepth 1 -print | sort
