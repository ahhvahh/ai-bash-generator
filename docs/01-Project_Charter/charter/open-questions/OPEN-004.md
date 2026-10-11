# OPEN-004 — Intercâmbio de dados entre capacidades

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Qual compromisso funcional de compatibilidade entre entradas, resultados e erros de capacidades é necessário para compor tarefas distintas?

## Contexto e evidência histórica

ADR-0003 fixa historicamente JSON UTF-8 em stdin/stdout de funções. CTR-0005 especifica a fronteira e limitações para encadeamento.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Pode impedir reutilização e composição confiáveis se contratos divergirem; o transporte específico pertence à etapa posterior.

## Bloqueadora

Não — o requisito funcional é tratável em Scope.

## Próxima ação

Confirmar critérios de compatibilidade, resultados e tratamento de falhas em alto nível.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/execucao/abi-stdout-stdin.md](../../../adr/execucao/abi-stdout-stdin.md)
- [docs/especificacao/contratos/function-json.md](../../../especificacao/contratos/function-json.md)
