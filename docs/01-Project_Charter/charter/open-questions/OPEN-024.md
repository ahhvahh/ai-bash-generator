# OPEN-024 — Privacidade e permissão para informações externas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais informações o produto pode compartilhar com provedores ou integrações externas, e como o solicitante controla essa autorização?

## Contexto e evidência histórica

CON-001 admite processamento externo opcional. ADR-0005, contratos de MCP e a integração de Google Mail descrevem tratamento de dados não confiáveis, permissões e auditoria.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta confidencialidade das solicitações e aderência à alternativa offline.

## Bloqueadora

Sim — política de saída de dados interfere diretamente em CON-001.

## Próxima ação

Decidir princípio de minimização de dados e autorização; registrar restrição canônica apropriada no Charter.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/especificacao/integracoes/google-mail.md](../../../especificacao/integracoes/google-mail.md)
- [docs/especificacao/contratos/mcp.md](../../../especificacao/contratos/mcp.md)
- [docs/adr/integracoes/orquestracao-mcp.md](../../../adr/integracoes/orquestracao-mcp.md)
- [docs/especificacao/modulos/tool-orchestrator.md](../../../especificacao/modulos/tool-orchestrator.md)
