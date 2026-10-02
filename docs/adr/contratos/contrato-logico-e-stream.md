# Separação entre contrato lógico e encoding de stream

![ADR](https://img.shields.io/badge/ADR-ADR--0009-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

O normalizador deve descrever intenção sem escolher detalhes de transporte.

## Problema

O contrato atual mistura `DataKind` e `StreamEncoding`, fazendo o normalizador escolher JSON_LINES ou TEXT antes de conhecer a capability.

## Restrições

- A mesma semântica pode existir em encodings diferentes.
- Compatibilidade lógica e de transporte são verificações distintas.

## Opções consideradas

### Manter DataContract único

Mais simples, porém acopla normalização ao transporte.

### LogicalDataContract + StreamContract

Separa semântica de framing/encoding e permite conversores explícitos.

## Decisão

Em refinamento. A proposta de separação não foi aprovada como decisão final.

## Justificativa

A escolha altera Protobuf, normalizador, busca, planner e validator.

## Consequências

MOD-0001, CTR-0001 e PRM-0001 não podem ser tratados como refinados.

## Dependências

- [ADR-0002](protobuf-e-textproto.md)
- [ADR-0003](../execucao/abi-stdout-stdin.md)

## Critérios de validação

- Definir campos do contrato lógico.
- Definir campos do contrato de stream.
- Definir regra de conversão ou rejeição entre encodings.
