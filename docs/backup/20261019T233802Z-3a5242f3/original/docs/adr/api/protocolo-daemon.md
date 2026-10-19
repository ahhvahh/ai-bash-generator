# Protocolo externo do daemon

![ADR](https://img.shields.io/badge/ADR-ADR--0015-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

O serviço é descrito como acessível por Unix Domain Socket, enquanto os contratos existentes se concentram no pipeline interno.

## Problema

Faltam envelopes de request, response e error, correlação, cancelamento, framing, tamanho máximo, EOF e versionamento funcional.

## Restrições

- `request_id` é criado pelo servidor.
- O protocolo precisa suportar erro estruturado e cancelamento.
- Artifact não é executado automaticamente.

## Opções consideradas

### Reusar mensagens internas diretamente

Acopla cliente ao pipeline interno.

### API externa própria sobre UDS

Cria contratos específicos para geração, health, erro e cancelamento.

## Decisão

Em refinamento. A proposta é uma API externa versionada, mas framing e envelopes ainda precisam ser definidos.

## Justificativa

Sem isso o fluxo de cliente, cancelamento e entrega de artifact não é suficientemente especificado.

## Consequências

DSG-0003, CTR-0004 e FLW-0005 permanecem bloqueados.

## Dependências

- [ADR-0002](../contratos/protobuf-e-textproto.md)

## Critérios de validação

- Definir framing e tamanho máximo.
- Definir envelopes e códigos de erro.
- Definir correlação e cancelamento.
- Definir negociação e versionamento.
- Definir semântica de conexão e EOF.
