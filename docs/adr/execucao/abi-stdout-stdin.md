# ABI de composição por stdout e stdin

![ADR](https://img.shields.io/badge/ADR-ADR--0003-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

Capabilities precisam ser compostas em um artifact Bash previsível.

## Problema

É necessário definir transporte de dados, diagnóstico e falha entre etapas.

## Restrições

- Cada processo possui um único stdin.
- Fan-out/fan-in não pode ser inventado pelo assembler.
- Saída funcional e diagnóstico usam canais distintos.

## Opções consideradas

### Arquivos temporários implícitos

Criam estado oculto.

### Variáveis Bash

Não atendem bem streams estruturados.

### ABI Unix

stdout para resultado, stdin para entrada e stderr para diagnóstico.

## Decisão

Adotar `producer stdout -> consumer stdin`; `exit 0` representa sucesso e demais códigos seguem contrato específico de exit code.

## Justificativa

É o mecanismo nativo do Bash e permite composição linear sem armazenamento intermediário oculto.

## Consequências

A V1 suporta pipelines lineares. Fan-out/fan-in exige capability explícita de tee, merge/join ou materialização.

## Dependências

- [ADR-0001](../pipeline/pipeline-hibrido.md)

## Critérios de validação

- `result_ref` estruturado corresponde a stdout/stdin.
- Branching implícito é rejeitado.
- stderr é diagnóstico.
