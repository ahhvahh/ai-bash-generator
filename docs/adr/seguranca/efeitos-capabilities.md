# Efeitos e autorização de capabilities

![ADR](https://img.shields.io/badge/ADR-ADR--0012-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

Contratos de entrada e saída não descrevem tudo que uma capability altera.

## Problema

`risk_level` não informa de forma verificável escrita, exclusão, rede, sinal de processo, restart de serviço ou privilégio.

## Restrições

- A policy precisa ser aplicada deterministicamente.
- O LLM não é autoridade para aprovar efeitos.

## Opções consideradas

### Apenas risk_level

Simples, porém insuficiente para autorização.

### CapabilityEffects estruturado

Declara efeitos de filesystem, processo, rede, serviço e privilégio e permite comparar pedido, capability e policy.

## Decisão

Em refinamento. A estrutura final de efeitos e política ainda não foi aprovada.

## Justificativa

A decisão afeta NormalizedTask, CapabilityDefinition, Validator e fluxo de aprovação.

## Consequências

Policy validation permanece parcialmente especificada.

## Dependências

- [ADR-0005](../integracoes/orquestracao-mcp.md)

## Critérios de validação

- Definir taxonomia de efeitos.
- Definir representação do efeito solicitado.
- Definir regra de comparação e rejeição.
