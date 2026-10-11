# OPEN-012 — Isolamento e complexidade das capacidades geradas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais limites de complexidade e previsibilidade são necessários para que novas capacidades sejam seguras e avaliáveis na V1?

## Contexto e evidência histórica

ADR-0011 limita historicamente a geração a uma função sem helpers/globals/código top-level; o Validator detalha controles estruturais.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta risco de efeitos inesperados, escopo inicial e critérios de validação.

## Bloqueadora

Sim — o alcance e as garantias de segurança da geração precisam ser confirmados.

## Próxima ação

Definir limites funcionais e garantias de comportamento; a sintaxe e os validadores ficam nas fases técnicas.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/execucao/isolamento-functions.md](../../../adr/execucao/isolamento-functions.md)
- [docs/especificacao/modulos/validator.md](../../../especificacao/modulos/validator.md)
