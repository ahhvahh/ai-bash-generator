# OPEN-020 — Garantias de validação antes de gerar e executar

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais validações e evidências são obrigatórias antes de permitir a execução automática de um script gerado?

## Contexto e evidência histórica

O Validator e o fluxo de correção descrevem validação estrutural, limites de tentativa e ausência de execução na fase antiga de geração. PCH-001 atual introduz execução automática, exigindo uma fronteira explícita.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Sem critérios de aprovação e tratamento de falha, um resultado sintaticamente válido pode produzir efeitos diferentes dos pretendidos.

## Bloqueadora

Sim — segurança e critérios de aceite para execução automática dependem desta definição.

## Próxima ação

Separar avaliação estática de garantia de execução e definir em Charter condições de aceite e falha; deixar ferramentas/rotinas de validação para Scope/Implementation.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/especificacao/modulos/validator.md](../../../especificacao/modulos/validator.md)
- [docs/especificacao/fluxos/correcao-validacao.md](../../../especificacao/fluxos/correcao-validacao.md)
- [docs/especificacao/prompts/capability-function-generator.md](../../../especificacao/prompts/capability-function-generator.md)
- [docs/especificacao/fluxos/geracao-bash.md](../../../especificacao/fluxos/geracao-bash.md)
