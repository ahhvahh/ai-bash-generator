# Cancelamento e timeout

![FLW](https://img.shields.io/badge/FLW-FLW--0005-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Definir cancelamento, deadlines e liberação de recursos durante uma requisição.

## Dependências

- [DSG-0003 — Runtime do daemon](../../desenho/runtime-daemon.md)
- [ADR-0015 — Protocolo externo](../../adr/api/protocolo-daemon.md)
- [CTR-0004 — API do daemon](../contratos/api-daemon.md)

## Gatilho

Cancelamento explícito, desconexão com semântica de cancelamento ou expiração de deadline.

## Pré-condições

BLOCKED. O protocolo externo ainda não define completamente cancelamento e conexão.

## Fluxo principal

Escopo esperado:

1. API identifica a requisição.
2. Pipeline recebe o cancelamento.
3. Contexto é propagado para inferência, PostgreSQL, tools/MCP, filesystem e publisher quando aplicável.
4. Operações pendentes são encerradas de forma segura.
5. Slot de fila e recursos são liberados.
6. O resultado de cancelamento é devolvido quando o canal ainda estiver disponível.

## Fluxos alternativos

A semântica de desconexão sem `CancelRequest` precisa ser definida no ADR-0015.

## Falhas e tratamento

Não deve permanecer inferência abandonada ocupando indefinidamente o runtime.

## Resultado

Requisição encerrada e recursos liberados.

## Critérios de aceite

- ADR-0015 refinado.
- DSG-0003 finalizado.
- Backpressure, queue timeout, inference timeout, tool timeout e request timeout definidos.
