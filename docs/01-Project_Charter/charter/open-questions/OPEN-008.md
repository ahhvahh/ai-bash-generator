# OPEN-008 — Limites da geração de novas capacidades

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A primeira versão deve criar apenas operações pontuais autocontidas, deixando outras modalidades de execução para cadastro ou evolução posterior?

## Contexto e evidência histórica

ADR-0007 restringe novas capacidades originadas da IA ao tipo FUNCTION; módulo e prompt do gerador detalham essa restrição.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta limites e expectativas sobre quais tipos de automação poderão ser produzidos sob demanda.

## Bloqueadora

Sim — é necessário confirmar a abrangência do produto na V1.

## Próxima ação

Aprovar alcance funcional da geração de capacidades, preservando a escolha do tipo de artefato para Scope/Implementation.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/geracao/capabilities-geradas.md](../../../adr/geracao/capabilities-geradas.md)
- [docs/especificacao/modulos/capability-function-generator.md](../../../especificacao/modulos/capability-function-generator.md)
- [docs/especificacao/prompts/capability-function-generator.md](../../../especificacao/prompts/capability-function-generator.md)
