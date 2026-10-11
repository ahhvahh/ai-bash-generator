# OPEN-002 — Orquestração da geração e composição de resultados

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A separação entre interpretação por IA, reutilização de capacidades e composição determinística atende ao resultado de produto pretendido?

## Contexto e evidência histórica

ADR-0001 prevê normalização por IA, geração apenas de capacidades ausentes e composição determinística do artefato. Os desenhos e o fluxo de geração desenvolvem esse caminho; trata-se de decisão técnica histórica a revalidar quanto ao benefício esperado.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

O resultado esperado deve distinguir geração, reaproveitamento e garantia de previsibilidade, sem impor a implementação nesta etapa.

## Bloqueadora

Não — a escolha do método pertence às etapas seguintes, desde que os objetivos de Charter sejam preservados.

## Próxima ação

Confirmar as garantias funcionais exigidas, verificar sua cobertura em OBJ-001/OBJ-002 e encaminhar a composição técnica a Scope/Implementation.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/pipeline/pipeline-hibrido.md](../../../adr/pipeline/pipeline-hibrido.md)
- [docs/desenho/pipeline-geracao.md](../../../desenho/pipeline-geracao.md)
- [docs/especificacao/fluxos/geracao-bash.md](../../../especificacao/fluxos/geracao-bash.md)
- [docs/especificacao/modulos/bash-output.md](../../../especificacao/modulos/bash-output.md)
- [docs/README.md](../../../README.md)
