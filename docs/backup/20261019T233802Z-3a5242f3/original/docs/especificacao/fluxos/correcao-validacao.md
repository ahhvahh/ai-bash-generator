# Correção após falha de validação

![FLW](https://img.shields.io/badge/FLW-FLW--0004-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Permitir uma correção controlada quando uma FUNCTION recém-gerada falhar na validação e a falha puder ser corrigida pelo gerador.

## Dependências

- [MOD-0003 — Capability Function Generator](../modulos/capability-function-generator.md)
- [MOD-0004 — Validator](../modulos/validator.md)
- [CTR-0001 — Protobuf](../contratos/pipeline-protobuf.md)
- [ADR-0013 — Sessão do gerador](../../adr/runtime/sessao-gerador.md)

## Gatilho

O Validator rejeita uma FUNCTION recém-gerada com issues estruturadas elegíveis para correção.

## Pré-condições

- a falha pertence à capability gerada, não ao DAG normalizado ou a capability existente;
- a política permite tentativa de correção;
- o orçamento de turnos não foi excedido.

## Fluxo principal

1. O Pipeline Manager recebe as issues estruturadas.
2. Envia ao Capability Function Generator somente a task afetada, contexto autorizado e issues.
3. O gerador retorna nova versão candidata da FUNCTION.
4. O Validator executa novamente as validações aplicáveis.
5. Se válida, a capability volta ao conjunto resolvido.
6. Se inválida, a requisição falha.

## Fluxos alternativos

### Falha estrutural da requisição

Não retorna ao gerador. O pipeline falha ou solicita informação conforme o tipo da inconsistência.

### Capability existente inválida

Não é reescrita pelo gerador. A versão é rejeitada e tratada conforme regras do catálogo/policy.

## Falhas e tratamento

A correção não cria loop indefinido. O limite final depende do ADR-0013.

## Resultado

FUNCTION candidata corrigida e validada ou falha estruturada.

## BLOCKED

O número máximo de tentativas e o contexto exato de correção dependem do ADR-0013.

## Critérios de aceite

- correção por LLM aplica-se somente à FUNCTION recém-gerada;
- issues são estruturadas;
- nenhuma task ou contrato é alterado para fazer a validação passar;
- artifact não é criado enquanto existir function inválida.
