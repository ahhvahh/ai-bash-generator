# OPEN-005 — Histórico e reprodutibilidade das capacidades

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A reutilização deve garantir reprodutibilidade, histórico de alterações e identificação da versão efetivamente usada?

## Contexto e evidência histórica

ADR-0004 adota catálogo PostgreSQL com versões imutáveis; desenho e especificação registram identidade, uso e ciclo de vida.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta auditabilidade e previsibilidade das soluções reutilizadas, sem impor banco de dados ou estrutura de tabelas no Charter.

## Bloqueadora

Não — requisito técnico de persistência deve ser consolidado posteriormente.

## Próxima ação

Decidir quais garantias de histórico e reprodutibilidade são requisitos de resultado do produto e vinculá-las a OBJ-002.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/persistencia/catalogo-capabilities.md](../../../adr/persistencia/catalogo-capabilities.md)
- [docs/desenho/catalogo-capabilities.md](../../../desenho/catalogo-capabilities.md)
- [docs/especificacao/persistencia/catalogo-capabilities.md](../../../especificacao/persistencia/catalogo-capabilities.md)
