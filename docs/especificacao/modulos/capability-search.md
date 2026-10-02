# Capability Search

![MOD](https://img.shields.io/badge/MOD-MOD--0002-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Localizar capabilities ativas compatíveis com a requisição completa e com tarefas individuais, sem usar LLM.

## Dependências

- [DSG-0002 — Catálogo de capabilities](../../desenho/catalogo-capabilities.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [PST-0001 — Persistência do catálogo](../persistencia/catalogo-capabilities.md)

## Responsabilidades

- candidate retrieval por intenção e Full Text Search;
- pruning determinístico por contratos, tipo, lifecycle e policy;
- busca composta e por tarefa;
- deduplicação global;
- respeito ao `SearchBudget`.

## Entradas

`SearchCapabilitiesRequest` contendo `NormalizedRequest` READY e orçamento.

## Saídas

Candidatos compostos e candidatos por tarefa.

## Restrições

`search_capabilities` não registra uso. O registro ocorre quando a versão completa é carregada.

**BLOCKED:** DSG-0002 não está `finalized`; não há contrato final para pinagem por versão e metadados versionáveis.

## Critérios de aceite

- Somente versões elegíveis entram na busca.
- FTS não substitui validação de compatibilidade.
- Zero candidatos é resultado válido.
- Limites globais e por tarefa são respeitados.

## Implementação relacionada

Referência histórica ao catálogo PostgreSQL; não verificada nesta adequação.
