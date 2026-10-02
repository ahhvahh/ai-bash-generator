# Isolamento de símbolos em functions geradas

![ADR](https://img.shields.io/badge/ADR-ADR--0011-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

O artifact pode incorporar múltiplas functions e helpers.

## Problema

Símbolos podem colidir e código top-level pode executar quando a definição é incorporada.

## Restrições

- Código gerado não pode produzir efeitos ao ser carregado.
- Regex isolada não é suficiente para análise segura de Bash.

## Opções consideradas

### Aceitar source livre

Permite colisão e execução top-level.

### Restringir estrutura e aplicar namespace

Permite somente definições, identifica símbolos e prefixa ou rejeita colisões.

## Decisão

Em refinamento. A política de namespace e a técnica de análise estrutural ainda não foram fechadas.

## Justificativa

A proposta é namespace por capability/version e validação estrutural antes da materialização.

## Consequências

A validação de FUNCTION permanece incompleta.

## Dependências

- [ADR-0007](../geracao/capabilities-geradas.md)

## Critérios de validação

- Proibir comandos top-level.
- Definir namespace canônico.
- Definir tratamento de globals e helpers.
- Definir analisador aceito na V1.
