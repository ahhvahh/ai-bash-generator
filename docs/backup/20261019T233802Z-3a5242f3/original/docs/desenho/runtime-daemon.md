# Runtime do daemon

![DSG](https://img.shields.io/badge/DSG-DSG--0003-0550ae?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Representar cliente, Unix Domain Socket, gerenciamento de requests, inferência, filas, cancelamento e lifecycle de modelo.

## Dependências

- [ADR-0013 — Sessão do gerador](../adr/runtime/sessao-gerador.md)
- [ADR-0014 — Lifecycle de modelos](../adr/runtime/lifecycle-modelos.md)
- [ADR-0015 — Protocolo externo](../adr/api/protocolo-daemon.md)

## Nível C4

`Container`

## Diagrama

BLOCKED. A fronteira de API e a estratégia de inferência ainda não possuem decisão refinada.

## Elementos e responsabilidades

Escopo esperado:

- cliente via UDS;
- API externa versionada;
- request correlation;
- Pipeline Manager;
- Model Manager;
- llama-server;
- propagação de deadline/cancelamento;
- fila e backpressure.

## Relações relevantes

A documentação existente indica `request_id` gerado pelo servidor e cancelamento propagado às operações internas, mas framing, envelopes e lifecycle de modelo ainda não estão definidos.

## Critérios para finalização

- ADR-0013, ADR-0014 e ADR-0015 em `refined`.
- Protocolo externo e limites definidos.
- Estratégia de modelo e fila definida.
