# OPEN-019 — Tratamento de solicitações incompletas ou fora do escopo

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

O que o solicitante deve receber quando faltarem informações indispensáveis, quando houver ambiguidade ou quando a solicitação não for suportada?

## Contexto e evidência histórica

Normalizador e FLW de informação ausente registram interrupção da geração sem fabricar valores; o prompt canônico descreve comportamento correspondente.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta confiança do usuário, integridade da execução automática e observabilidade do motivo de não atendimento.

## Bloqueadora

Sim — tratamento de solicitações que não podem ser executadas é uma garantia funcional importante.

## Próxima ação

Definir comportamento esperado e condições de não atendimento; tratar modelos de erro em Scope.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/especificacao/fluxos/informacao-ausente.md](../../../especificacao/fluxos/informacao-ausente.md)
- [docs/especificacao/modulos/request-normalizer.md](../../../especificacao/modulos/request-normalizer.md)
- [docs/especificacao/prompts/request-normalizer.md](../../../especificacao/prompts/request-normalizer.md)
