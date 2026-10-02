# Validator

![MOD](https://img.shields.io/badge/MOD-MOD--0004-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Validar deterministicamente o `GenerationPlan`, capabilities resolvidas e novas functions antes de qualquer materialização.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0003 — ABI](../../adr/execucao/abi-stdout-stdin.md)
- [ADR-0010 — Binding de invocação](../../adr/execucao/binding-invocacao.md)
- [ADR-0011 — Isolamento de functions](../../adr/execucao/isolamento-functions.md)
- [ADR-0012 — Efeitos](../../adr/seguranca/efeitos-capabilities.md)
- [CTR-0001 — Protobuf](../contratos/pipeline-protobuf.md)

## Responsabilidades

A ordem prevista é:

1. validação Protobuf;
2. grafo;
3. contratos;
4. versões;
5. policy;
6. preview determinístico do Bash;
7. `bash -n`;
8. ShellCheck;
9. dependências.

## Entradas

`ValidationRequest` com plano e definições completas das versões utilizadas.

## Saídas

`ValidationResult` com `valid`, plano, capabilities resolvidas e issues estruturadas.

## Restrições

- O script não é executado.
- SCRIPT/APPLICATION devem ter integridade externa verificável quando aplicável.
- SERVICE deve ter cliente controlado conforme contrato.
- Nova capability de LLM é FUNCTION.
- ShellCheck indisponível deve resultar em falha explícita na política atual.

**BLOCKED:** binding, isolamento de function e efeitos ainda não estão refinados. Semântica de exit codes e testes funcionais também permanece pendente.

## Critérios de aceite

- Ciclos e referências inválidas são rejeitados.
- Contratos incompatíveis são rejeitados.
- Capability existente sem versão resolvida é rejeitada.
- Policy é aplicada fora do LLM.
- Falha na segunda validação após correção encerra a geração.

## Implementação relacionada

Referência histórica: validador do pipeline; não verificado nesta adequação.
