# Contrato de MCP e tools de geração

![CTR](https://img.shields.io/badge/CTR-CTR--0002-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Definir como o gerador solicita tools e como o ai-bash-gen autoriza e devolve resultados.

## Dependências

- [ADR-0005 — Orquestração MCP](../../adr/integracoes/orquestracao-mcp.md)
- [MOD-0006 — Tool/MCP Orchestrator](../modulos/tool-orchestrator.md)

## Tipo

`mensagem | MCP | interface`

## Entrada

Uma solicitação possui identidade da chamada e exatamente uma operação de tool, como:

- carregar uma capability;
- chamar uma tool de MCP generation-time.

MCP genérico transporta payload tipado por schema e representação TextProto na fronteira LLM.

## Saída

Resultado correlacionado por `call_id`, contendo payload válido ou erro estruturado.

## Erros

Condições mínimas:

- tool não autorizada;
- schema inválido;
- timeout;
- limite excedido;
- MCP indisponível;
- versão de capability inexistente ou não elegível;
- resposta acima do limite.

## Regras e restrições

- Allowlist pertence ao agente e é aplicada pela aplicação.
- Generation-time tool não vira runtime capability automaticamente.
- O modelo não recebe credenciais.
- Resposta externa é tratada como conteúdo não confiável.
- Tool call possui timeout e orçamento.
- Telemetria mínima: request, agent, servidor, tool, duração, status e código de erro.
- Dados sensíveis não são registrados integralmente em logs por padrão.

## Compatibilidade

MCPs locais preferem `stdio`. Integrações externas devem ter processo e política de rede próprios quando necessário.

## Critérios de aceite

- Chamada não autorizada nunca chega ao MCP.
- Resposta é validada antes de retornar ao modelo.
- Falha de tool não executa o artifact.
- Limites globais e do agente são combinados pelo valor mais restritivo.
