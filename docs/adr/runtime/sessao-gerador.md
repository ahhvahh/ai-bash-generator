# Sessão e orçamento de contexto do gerador

![ADR](https://img.shields.io/badge/ADR-ADR--0013-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

Cada turno pode acumular request normalizado, candidatos, definições de capabilities, resultados de tools e plano.

## Problema

Sem orçamento explícito, o contexto do modelo pode exceder o limite e perder instruções ou dados necessários.

## Restrições

- Hardware de referência é limitado.
- Tool loop precisa de número máximo de turnos e resultados limitados.

## Opções consideradas

### Reenviar todo o histórico

Simples, mas cresce sem limite.

### GeneratorSession controlada pelo Pipeline Manager

Mantém cache, índice, token budget e estado de turno.

## Decisão

Em refinamento. Limites e estratégia de compactação ou rejeição ainda não foram definidos.

## Justificativa

A revisão propõe limites de contexto, reserva de saída, tamanho de tool result/source e número máximo de turnos.

## Consequências

MOD-0003 e FLW-0001 permanecem bloqueados para refinamento final.

## Dependências

- [ADR-0001](../pipeline/pipeline-hibrido.md)

## Critérios de validação

- Definir limites configuráveis e defaults.
- Definir estimativa de tokens.
- Definir comportamento ao exceder orçamento.
