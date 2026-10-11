# OPEN-015 — Disponibilidade e flexibilidade da inferência

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Que comportamento de disponibilidade deve ser garantido quando um mecanismo de inferência estiver ausente, indisponível ou for substituído?

## Contexto e evidência histórica

ADR-0014 não decidiu se V1 usa um modelo ou vários; os contratos de agentes e manutenção de inferência mostram dependências da decisão.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Relaciona-se à exigência de operação offline e ao limite de recursos de CON-001/CON-002.

## Bloqueadora

Sim — é necessário especificar o mínimo garantido para o funcionamento offline.

## Próxima ação

Revalidar o comportamento esperado com CON-001/ASM-001; deixar gerenciamento e recarga de modelos para Implementation.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/runtime/lifecycle-modelos.md](../../../adr/runtime/lifecycle-modelos.md)
- [docs/especificacao/contratos/agentes.md](../../../especificacao/contratos/agentes.md)
- [docs/especificacao/runtime/manutencao-inferencia.md](../../../especificacao/runtime/manutencao-inferencia.md)
