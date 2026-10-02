# Correção após falha de validação

![FLW](https://img.shields.io/badge/FLW-FLW--0004-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Permitir no máximo uma correção do plano quando a primeira validação determinística falhar.

## Dependências

- [MOD-0003 — Bash Generator](../modulos/bash-generator.md)
- [MOD-0004 — Validator](../modulos/validator.md)
- [CTR-0001 — Protobuf](../contratos/pipeline-protobuf.md)

## Gatilho

O Validator retorna `valid=false` com issues estruturadas.

## Pré-condições

- existe um plano de geração;
- a política permite uma tentativa de correção;
- o orçamento de turnos não foi excedido.

## Fluxo principal

1. O Pipeline Manager recebe `ValidationIssue`.
2. Envia ao gerador o contexto necessário e as issues.
3. O gerador retorna plano corrigido.
4. O Validator executa novamente a sequência completa de validação.
5. Se válido, o fluxo segue para publicação/materialização.
6. Se inválido, a requisição falha.

## Fluxos alternativos

### Retry indisponível

A requisição falha sem novo turno.

## Falhas e tratamento

A segunda falha encerra o processamento; não existe loop indefinido de autocorreção.

## Resultado

Plano corrigido validado ou falha estruturada.

## BLOCKED

O conteúdo exato do turno de correção depende do orçamento de contexto definido pelo ADR-0013.

## Critérios de aceite

- No máximo uma tentativa adicional.
- Issues são estruturadas.
- O artifact não é criado após validação inválida.
