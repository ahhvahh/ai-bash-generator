# Publicação de capability e materialização independentes

![ADR](https://img.shields.io/badge/ADR-ADR--0006-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

Uma geração validada pode publicar uma capability e materializar um arquivo Bash.

## Problema

PostgreSQL e filesystem não compartilham uma transação atômica.

## Restrições

- Não simular transação distribuída.
- Ambas as operações precisam ser repetíveis.
- Publicação concorrente precisa ser idempotente.

## Opções consideradas

### Acoplar rollback entre banco e filesystem

Complexo e frágil.

### Operações independentes após validação

Cada operação controla sua atomicidade e retry.

## Decisão

Após validação, Capability Publisher e Bash Output são operações independentes e repetíveis.

## Justificativa

Evita estado distribuído parcialmente confirmado.

## Consequências

Falha de publicação não invalida automaticamente um artifact já materializado; falha de filesystem não desfaz publicação válida.

## Dependências

- [ADR-0004](../persistencia/catalogo-capabilities.md)

## Critérios de validação

- Publicação usa idempotency key e fingerprint.
- Artifact usa gravação atômica.
- Resultados podem ser reportados separadamente.
