# OPEN-009 — Critério de equivalência para reutilização

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A igualdade exata de propósito, entrada e saída e a manutenção da mesma versão durante a solicitação continuam sendo os requisitos da V1?

## Contexto e evidência histórica

ADR-0008 e o módulo de busca documentam matching exato e pinagem. A decisão já aparece em OBJ-002 e OPEN-001; este registro pede revisão, não cria uma decisão paralela.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Mudar o critério afeta o principal resultado de OBJ-002 e o conjunto de testes de reutilização.

## Bloqueadora

Sim — qualquer alteração exigiria revisão formal de OBJ-002.

## Próxima ação

Confirmar ou revisar explicitamente OBJ-002 e tratar em OPEN-001 apenas as métricas que ainda faltam.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/catalogo/pinagem-versao-capability.md](../../../adr/catalogo/pinagem-versao-capability.md)
- [docs/especificacao/modulos/capability-search.md](../../../especificacao/modulos/capability-search.md)
