# API externa do daemon

![CTR](https://img.shields.io/badge/CTR-CTR--0004-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Definir o protocolo cliente-servidor do daemon sobre Unix Domain Socket.

## Dependências

- [DSG-0003 — Runtime do daemon](../../desenho/runtime-daemon.md)
- [ADR-0015 — Protocolo externo](../../adr/api/protocolo-daemon.md)

## Tipo

`API | Protobuf`

## Entrada

BLOCKED. A documentação existente indica necessidade de pelo menos:

- geração de Bash;
- health;
- cancelamento.

O envelope, framing e campos finais não estão decididos.

## Saída

BLOCKED. Deve haver resposta correlacionada e entrega explícita do artifact ou referência equivalente, conforme decisão arquitetural.

## Erros

Precisam incluir códigos de protocolo, validação, timeout, cancelamento, pipeline e indisponibilidade.

## Regras e restrições

Já é estável que:

- o transporte é local por Unix Domain Socket;
- `request_id` é gerado pelo servidor;
- artifact não é executado automaticamente.

Ainda faltam:

- frame e tamanho máximo;
- multiplexing ou uma requisição por conexão;
- EOF;
- cancelamento;
- timeouts;
- versão funcional;
- envelope de erro.

## Compatibilidade

A política de versionamento depende do ADR-0015 e da pendência de versão funcional do protocolo.

## Critérios de aceite

- ADR-0015 refinado.
- DSG-0003 finalizado.
- Todos os envelopes e erros definidos.
- Cancelamento e limites possuem semântica inequívoca.
