# OPEN-003 — Contratos estruturados na interação com inferência

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais garantias de clareza, validade e interoperabilidade das solicitações são indispensáveis, independentemente do formato de contrato?

## Contexto e evidência histórica

ADR-0002 registra Protobuf no plano de controle e TextProto na fronteira de inferência. O contrato de pipeline e o prompt do normalizador usam representações estruturadas; a opção técnica não é automaticamente um compromisso de Charter.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Define a necessidade de resultados interpretáveis e verificáveis sem fixar serialização no Charter.

## Bloqueadora

Não — formato e schema são decisões de Scope/Implementation.

## Próxima ação

Refinar o resultado verificável de interoperabilidade, sem transportar formatos físicos para Charter.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/contratos/protobuf-e-textproto.md](../../../adr/contratos/protobuf-e-textproto.md)
- [docs/especificacao/contratos/pipeline-protobuf.md](../../../especificacao/contratos/pipeline-protobuf.md)
- [docs/especificacao/prompts/request-normalizer.md](../../../especificacao/prompts/request-normalizer.md)
