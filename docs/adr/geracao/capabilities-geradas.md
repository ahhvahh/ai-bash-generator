# Capabilities geradas diretamente apenas como FUNCTION

![ADR](https://img.shields.io/badge/ADR-ADR--0007-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

O gerador pode preencher lacunas criando comportamento reutilizável.

## Problema

SCRIPT, APPLICATION e SERVICE dependem de artefatos externos concretos que o LLM não consegue materializar e validar somente pelo plano.

## Restrições

- O LLM não executa código gerado.
- Dependências externas precisam de checksum ou contrato administrado.
- Ativação não é automática.

## Opções consideradas

### Permitir todos os tipos

Mistura geração com provisionamento externo.

### Permitir somente FUNCTION na primeira versão

Mantém o comportamento incorporável dentro do artifact.

## Decisão

Na primeira versão, novas capabilities produzidas diretamente pelo LLM são somente do tipo `FUNCTION`. Outros tipos entram por fluxo administrativo.

## Justificativa

Reduz dependências externas não verificáveis durante a geração.

## Consequências

Functions ainda dependem das regras de isolamento do [ADR-0011](../execucao/isolamento-functions.md).

## Dependências

- [ADR-0001](../pipeline/pipeline-hibrido.md)
- [ADR-0006](../pipeline/publicacao-materializacao.md)

## Critérios de validação

- GeneratedCapability de origem LLM não aceita SCRIPT/APPLICATION/SERVICE.
- Publicação ocorre como candidate, sem ativação automática.
