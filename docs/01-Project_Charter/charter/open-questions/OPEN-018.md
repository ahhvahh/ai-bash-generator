# OPEN-018 — Operações e cenários atendidos pela primeira versão

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais operações locais e classes de solicitação devem integrar a V1 e quais devem ficar explicitamente fora dela?

## Contexto e evidência histórica

README principal e ADR-0011 citam comandos, arquivos, diretórios e consultas de recursos. Não há uma delimitação de alcance completa e verificada no Charter.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Sem limite de produto, aceitação de geração e execução automática podem ter expectativas incompatíveis.

## Bloqueadora

Sim — delimitação de produto necessária ao gate de Charter.

## Próxima ação

Consolidar lista de capacidades-alvo por finalidade e propor OBJ/NOBJ específicos quando aplicável.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [README.md](../../../../README.md)
- [docs/adr/execucao/isolamento-functions.md](../../../adr/execucao/isolamento-functions.md)
- [docs/especificacao/modulos/request-normalizer.md](../../../especificacao/modulos/request-normalizer.md)
