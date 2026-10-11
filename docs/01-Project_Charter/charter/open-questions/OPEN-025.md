# OPEN-025 — Administração local, auditoria e manutenção da inferência

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais capacidades de manutenção, inspeção e auditoria devem estar disponíveis ao responsável local pelo sistema?

## Contexto e evidência histórica

CTR-0003 contempla ajustes de agentes e modelos; OPS-0001 registra ausência de CLI/hot reload atuais e propõe manutenção. README principal descreve logs e observabilidade.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Influencia controle administrativo, suporte e rastreabilidade de falhas, sem impor interface de operação nesta etapa.

## Bloqueadora

Não — detalhes de CLI, arquivos e recarga são Implementation.

## Próxima ação

Decidir o nível de manutenção e evidência de auditoria que compõe o resultado do produto.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/especificacao/contratos/agentes.md](../../../especificacao/contratos/agentes.md)
- [docs/especificacao/runtime/manutencao-inferencia.md](../../../especificacao/runtime/manutencao-inferencia.md)
- [README.md](../../../../README.md)
- [docs/pendencias.md](../../../pendencias.md)
