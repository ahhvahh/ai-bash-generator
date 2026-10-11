# OPEN-017 — Concorrência e previsibilidade de tarefas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais garantias de paralelismo, ordenação, limites de recursos e falhas devem ser observáveis nas automações?

## Contexto e evidência histórica

ADR-0016 registra limite técnico de quatro tasks por artifact; assembler e fluxo ainda apresentam pendências de seleção, buffering e falhas.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta desempenho, consumo de recursos e integridade de resultados quando existem tarefas independentes.

## Bloqueadora

Não — algoritmo e limite de concorrência operacional devem ser tratados após as metas de produto.

## Próxima ação

Validar a necessidade de execução simultânea e seus critérios de sucesso; manter escalonamento técnico pendente.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/execucao/limite-paralelismo-dag.md](../../../adr/execucao/limite-paralelismo-dag.md)
- [docs/especificacao/modulos/bash-output.md](../../../especificacao/modulos/bash-output.md)
- [docs/especificacao/fluxos/geracao-bash.md](../../../especificacao/fluxos/geracao-bash.md)
- [docs/pendencias.md](../../../pendencias.md)
