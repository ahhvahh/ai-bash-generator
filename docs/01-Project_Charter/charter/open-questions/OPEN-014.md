# OPEN-014 — Orçamento de processamento e recuperação

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Que limites de custo, tempo e tentativas de geração são aceitáveis para o solicitante sem comprometer completude ou segurança?

## Contexto e evidência histórica

ADR-0013 está em refinamento: propõe contexto focado na tarefa, mas sem limites numéricos de turnos e tokens. O módulo de geração e o fluxo de correção dependem disso.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta expectativas de latência, uso local de recursos e uso opcional de provedores externos.

## Bloqueadora

Não — números e algoritmo de orçamento pertencem às etapas seguintes, após metas de produto.

## Próxima ação

Definir exigências mensuráveis de custo e duração quando relevantes; elaborar orçamento técnico depois.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/runtime/sessao-gerador.md](../../../adr/runtime/sessao-gerador.md)
- [docs/especificacao/modulos/capability-function-generator.md](../../../especificacao/modulos/capability-function-generator.md)
- [docs/especificacao/fluxos/correcao-validacao.md](../../../especificacao/fluxos/correcao-validacao.md)
- [docs/pendencias.md](../../../pendencias.md)
