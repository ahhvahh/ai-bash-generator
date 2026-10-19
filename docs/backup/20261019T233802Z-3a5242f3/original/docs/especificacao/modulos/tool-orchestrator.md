# Tool/MCP Orchestrator

![MOD](https://img.shields.io/badge/MOD-MOD--0006-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Autorizar, validar, executar e auditar `get_capability` e MCPs generation-time em nome do pipeline.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0005 — Orquestração MCP](../../adr/integracoes/orquestracao-mcp.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [CTR-0002 — MCP](../contratos/mcp.md)

## Responsabilidades

- validar allowlist do agente;
- validar schema e limites da chamada;
- aplicar timeout;
- consultar cache por request/version;
- carregar capability autorizada;
- executar MCP permitido;
- sanitizar e limitar respostas;
- registrar telemetria operacional.

## Entradas

`GeneratorToolRequest` autorizado pelo pipeline.

## Saídas

`GeneratorToolResponse` ou erro estruturado.

## Restrições

- O LLM não acessa MCP diretamente.
- Credenciais não entram em prompt.
- `search_capabilities` não é substituído pelo tool loop.
- Dados externos podem conter conteúdo hostil e devem ser tratados como dados não confiáveis.

**BLOCKED:** a chave definitiva para carregar uma versão depende de ADR-0008. Política completa de prompt injection permanece pendente.

## Critérios de aceite

- MCP fora da allowlist é rejeitado.
- Cada chamada possui correlação, timeout e status.
- Detalhe de capability é carregado no máximo uma vez por request/version.
- Corpo sensível de integrações não é registrado integralmente em logs por padrão.

## Implementação relacionada

Referência histórica ao Tool Orchestrator; não verificado nesta adequação.
