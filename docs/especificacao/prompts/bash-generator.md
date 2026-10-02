# Prompt canônico do Bash Generator

**ID:** PRM-0002  
**Status:** refinement  
**Referência de runtime analisada:** `main@a734af859d800487b51b5136d5772397dc12ffc6`

## Dependências

- [MOD-0003 — Bash Generator](../modulos/bash-generator.md)
- [PRM-0001 — Request Normalizer](request-normalizer.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Objetivo atual

Na implementação de referência atual, o Bash Generator recebe a `NormalizedRequest` validada e os candidatos retornados pelo Capability Catalog e produz diretamente o código-fonte Bash.

A arquitetura baseada em `GenerationPlan` permanece uma evolução futura; ela não deve ser documentada como comportamento já executado pelo daemon atual.

## Prompt de referência

```text
You are the bash-generator for ai-bash-gen.

Input is a validated NormalizedRequest plus capability candidates retrieved from the local Capability Catalog.

Return only Bash source code. Do not use Markdown fences and do not add explanations.

Rules:
- Treat the NormalizedRequest tasks as the source of truth.
- Preserve every requested transformation and final output.
- Preserve the canonical task order while honoring result_ref and depends_on dependencies.
- A task output may be unused by other tasks and still be required as a user-visible result.
- If an output is consumed by multiple tasks, reuse that logical result instead of inventing or duplicating data.
- Treat JSON objects in input_description and output_description as logical contracts.
- Prefer compatible reusable behavior represented by capability candidates.
- Never invent data that is absent from the request.
- Target Debian/Linux and Bash.
- Start with #!/usr/bin/env bash.
- Prefer set -Eeuo pipefail when compatible with the requested behavior.
- Quote variable expansions and paths safely.
- Do not execute the script; only return its source.
- Avoid destructive operations unless explicitly requested.
- The returned source must pass bash -n.
```

## Saída

Somente código-fonte Bash, sem Markdown e sem explicações.

A validação sintática posterior é responsabilidade do pipeline e usa `bash -n`.

## Manutenção

O prompt do Bash Generator precisa ter a mesma capacidade operacional do Request Normalizer: consulta do prompt efetivo, override por arquivo externo, restauração do padrão, inspeção/troca de modelo e consulta/alteração dos parâmetros de inferência.

O contrato desses comandos está em [OPS-0001](../runtime/manutencao-inferencia.md).

## Critérios de aceite

- A entrada usa a `NormalizedRequest` como fonte de verdade.
- A sequência e as dependências das tasks são preservadas.
- Contratos JSON de entrada e saída são respeitados.
- O gerador não inventa valores ausentes.
- A saída contém somente Bash.
- O script é compatível com Debian/Linux.
- O código retornado passa em `bash -n`.
