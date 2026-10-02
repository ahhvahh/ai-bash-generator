# Catálogo de capabilities

![DSG](https://img.shields.io/badge/DSG-DSG--0002-0550ae?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Representar busca, versionamento, lifecycle, telemetria e publicação de capabilities.

## Dependências

- [ADR-0004 — PostgreSQL e versões imutáveis](../adr/persistencia/catalogo-capabilities.md)
- [ADR-0008 — Identidade e pinagem de versão](../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0012 — Efeitos e autorização](../adr/seguranca/efeitos-capabilities.md)

## Nível C4

`Component`

## Diagrama

BLOCKED. O desenho final não deve congelar a posição dos metadados pesquisáveis nem o contrato de autorização antes dos ADRs dependentes serem refinados.

## Elementos e responsabilidades

Já são estáveis:

- identidade lógica da capability;
- versões imutáveis;
- versão ativa única;
- telemetria por versão;
- publicação idempotente.

Ainda estão em decisão:

- campos estáveis versus versionados;
- pinagem entre search e detail;
- efeitos estruturados usados por policy.

## Relações relevantes

A busca deve retornar somente versões ativas. O detalhe consumido pelo gerador precisa corresponder à versão avaliada pelo pruning, mas o contrato definitivo está em ADR-0008.

## Critérios para finalização

- ADR-0008 em `refined`.
- ADR-0012 em `refined`.
- Definição inequívoca de identidade, versão, search candidate e policy metadata.
