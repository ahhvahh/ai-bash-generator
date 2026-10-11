# OPEN-006 — Controle do acesso a ferramentas e integrações

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

O produto deve permitir integrações durante a geração e quais limites de autorização, rastreabilidade e confiança são obrigatórios?

## Contexto e evidência histórica

ADR-0005 descreve orquestração central de ferramentas/MCP com validação e credenciais fora do modelo. Contrato e módulo estabelecem permissões e limites.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta exposição de dados a terceiros e o limite de autoridade delegado ao processamento automático.

## Bloqueadora

Sim — as permissões e o uso de integrações afetam diretamente as restrições declaradas no Charter.

## Próxima ação

Confirmar a política de autorização de integrações em nível de produto; detalhar MCP, schemas e timeouts em Scope/Implementation.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/integracoes/orquestracao-mcp.md](../../../adr/integracoes/orquestracao-mcp.md)
- [docs/especificacao/contratos/mcp.md](../../../especificacao/contratos/mcp.md)
- [docs/especificacao/modulos/tool-orchestrator.md](../../../especificacao/modulos/tool-orchestrator.md)
