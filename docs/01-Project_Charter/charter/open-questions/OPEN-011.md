# OPEN-011 — Composição de capacidades heterogêneas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

O produto deve reutilizar capacidades existentes mesmo quando suas implementações internas sejam diferentes, sem alterar o resultado esperado?

## Contexto e evidência histórica

ADR-0010 prevê interface uniforme fornecida pela capacidade; CTR-0005 especifica essa interface.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Amplia potencial de reaproveitamento e limita dependência do produto de formas internas de execução.

## Bloqueadora

Não — o mecanismo de adaptação é uma decisão técnica posterior.

## Próxima ação

Decidir a abrangência da interoperabilidade esperada e vincular o requisito a OBJ-002.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/execucao/binding-invocacao.md](../../../adr/execucao/binding-invocacao.md)
- [docs/especificacao/contratos/function-json.md](../../../especificacao/contratos/function-json.md)
