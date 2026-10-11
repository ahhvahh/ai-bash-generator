# OPEN-010 — Separação entre intenção e mecanismos técnicos

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A tarefa deve ser descrita por propósito, dados necessários e resultado esperado, sem impor antecipadamente uma ferramenta de execução?

## Contexto e evidência histórica

ADR-0009 separa contrato lógico e transporte; normalizador e seu prompt evitam escolher implementação.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Preserva neutralidade de solução e favorece reuso, mas contratos físicos são da etapa seguinte.

## Bloqueadora

Não — a semântica funcional pode ser refinada em Scope.

## Próxima ação

Validar que a intenção do solicitante seja preservada e retirar especificações de transporte do Charter.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/contratos/contrato-logico-e-stream.md](../../../adr/contratos/contrato-logico-e-stream.md)
- [docs/especificacao/modulos/request-normalizer.md](../../../especificacao/modulos/request-normalizer.md)
- [docs/especificacao/prompts/request-normalizer.md](../../../especificacao/prompts/request-normalizer.md)
