# Google Mail MCP

**ID:** INT-0001  
**Status:** refinement

## Objetivo

Definir a integração de leitura de e-mails utilizada como tool de geração.

## Dependências

- [CTR-0002 — MCP](../contratos/mcp.md)
- [MOD-0006 — Tool/MCP Orchestrator](../modulos/tool-orchestrator.md)

## Operações previstas

- `search_emails`: pesquisa controlada e resposta resumida.
- `get_email`: obtém uma mensagem específica.
- `get_thread`: obtém uma conversa com limites de quantidade e tamanho.

Na primeira versão, anexos são apenas descritos; o conteúdo do anexo não é necessário.

## Restrições

A primeira versão é somente leitura. Não deve enviar, apagar, mover, alterar labels, marcar como lido ou modificar a caixa postal.

Toda chamada passa pelo Tool/MCP Orchestrator, precisa estar na allowlist do agente, possui timeout e limites de resposta.

O conteúdo retornado é dado não confiável e não pode alterar policy, allowlist ou instruções do sistema.

## Auditoria

Registrar request, agente, servidor, tool, duração, status e código de erro. Conteúdo integral da mensagem não deve ser registrado por padrão.

## Pendências

- política completa contra prompt injection;
- critérios finais de truncamento;
- operação segura do acesso externo.

## Critérios de aceite

- Somente agentes autorizados acessam a integração.
- Todas as operações expostas são de leitura.
- Respostas acima dos limites são truncadas ou rejeitadas.
