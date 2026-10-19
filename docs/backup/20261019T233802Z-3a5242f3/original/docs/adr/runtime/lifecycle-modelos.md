# Lifecycle de modelos de inferência

![ADR](https://img.shields.io/badge/ADR-ADR--0014-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

A documentação prevê agentes distintos e admite modelos distintos, mas também considera ambiente com apenas um modelo carregado.

## Problema

Não está definido como alternar modelos quando request-normalizer e bash-generator usam modelos diferentes.

## Restrições

- Hardware de referência pode suportar apenas um modelo simultâneo.
- Troca de modelo precisa de timeout, fila, health check e rollback quando aplicável.

## Opções consideradas

### Um único modelo na V1

Dois agentes com prompts diferentes compartilham o mesmo GGUF.

### Reload entre etapas

Introduz custo e falha de carregamento.

### Workers separados

Exige mais memória e supervisão.

## Decisão

Em refinamento. A revisão recomenda modelo único na V1, mas a decisão não está fechada.

## Justificativa

O contrato de configuração de agentes depende desta escolha.

## Consequências

DSG-0003 e CTR-0003 permanecem bloqueados.

## Dependências

- [ADR-0013](sessao-gerador.md)

## Critérios de validação

- Escolher estratégia da V1.
- Definir fila e falha de inferência.
- Definir comportamento de configuração incompatível.
