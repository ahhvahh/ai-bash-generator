# PostgreSQL e versões imutáveis de capabilities

![ADR](https://img.shields.io/badge/ADR-ADR--0004-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

Capabilities reutilizáveis precisam de identidade, lifecycle e histórico.

## Problema

Uma capability mutável impediria reproduzir exatamente a versão entregue a uma geração anterior.

## Restrições

- Somente versão ativa entra na busca normal.
- Versões publicadas são imutáveis.
- Uso aponta para a versão efetivamente carregada.
- Acesso ao banco é local.

## Opções consideradas

### Arquivos locais

Insuficientes para concorrência, busca e lifecycle.

### PostgreSQL com versão mutável

Perde rastreabilidade.

### PostgreSQL com identidade e versões imutáveis

Separa identidade lógica do conteúdo versionado.

## Decisão

Usar PostgreSQL com identidade `capability`, versões imutáveis em `capability_version`, uma versão ativa por capability e telemetria append-only por versão.

## Justificativa

Fornece integridade transacional e identificação exata do conteúdo consumido.

## Consequências

A localização de metadados pesquisáveis e a pinagem entre busca e detalhe permanecem abertas no [ADR-0008](../catalogo/pinagem-versao-capability.md).

## Dependências

- [ADR-0003](../execucao/abi-stdout-stdin.md)

## Critérios de validação

- No máximo uma versão ativa por capability.
- `capability_usage` referencia `capability_version_id`.
- Versões não ativas não entram na busca normal.
