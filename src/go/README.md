# Implementação Go

Este diretório contém o módulo Go do `ai-bash-gen`.

## Estado

O bootstrap inicial é intencionalmente pequeno. Ele fixa a estrutura de projeto, caminhos padrão, contratos básicos de estágios e validações determinísticas que não dependem das decisões ainda abertas na revisão de arquitetura V2.

A API externa por Unix Domain Socket não é implementada neste bootstrap porque `docs/analysis/ARCHITECTURE_REVIEW_V2.md` ainda exige a definição de `api.proto` antes do daemon completo.

## Requisitos

- Go 1.22 ou superior;
- `protoc` apenas para regenerar os bindings Protobuf;
- `protoc-gen-go` apenas para regenerar os bindings Protobuf.

No Debian:

```bash
sudo apt install protobuf-compiler
make tools
```

## Comandos

```bash
make test
make vet
make build
./bin/ai-bash-gen --version
./bin/ai-bash-gen --show-paths
```

Para gerar os bindings do schema existente:

```bash
make proto
```

Os arquivos gerados serão colocados em `src/go/gen/` de acordo com o `go_package` definido em `proto/ai_bash_gen/v1/pipeline.proto`.

## Estrutura

```text
src/go/
├── cmd/ai-bash-gen/       # executável
├── internal/buildinfo/    # versão/build
├── internal/output/       # regras determinísticas do artefato Bash
├── internal/pipeline/     # nomes e contratos básicos dos estágios
├── internal/platform/     # caminhos padrão Linux/Debian
├── Makefile
└── go.mod
```
