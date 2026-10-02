# Binding determinístico de invocação

![ADR](https://img.shields.io/badge/ADR-ADR--0010-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

O GenerationPlan possui argumentos nomeados, mas o Bash Output precisa convertê-los em sintaxe real da implementation.

## Problema

Um valor `path=/tmp` pode ser posicional, flag, boolean, ambiente, stdin ou usar sintaxe `--path=value`.

## Restrições

- O assembler não pode inferir convenções.
- SCRIPT e APPLICATION precisam declarar a forma de materialização de cada parâmetro.

## Opções consideradas

### Inferência pelo nome

Não determinística.

### Binding explícito por parâmetro

Declara tipo, posição, flag, repetição, separador e obrigatoriedade.

## Decisão

Em refinamento. Nenhum modelo final de binding foi aprovado.

## Justificativa

A revisão propõe tipos POSITIONAL, FLAG_VALUE, FLAG_BOOLEAN, ENVIRONMENT e STDIN.

## Consequências

Assembler e validação completa permanecem bloqueados.

## Dependências

- [ADR-0003](abi-stdout-stdin.md)

## Critérios de validação

- Definir tipos de binding suportados.
- Definir quoting e repetição.
- Definir ordenação de argumentos.
- Definir tratamento de valores ausentes.
