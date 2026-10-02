# Request Normalizer

![MOD](https://img.shields.io/badge/MOD-MOD--0001-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Transformar linguagem natural em uma requisição estruturada, sem escolher comandos, capabilities ou implementação Bash.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [CTR-0001 — Protobuf do pipeline](../contratos/pipeline-protobuf.md)
- [PRM-0001 — Prompt do normalizador](../prompts/request-normalizer.md)

## Responsabilidades

- decompor o objetivo em tarefas pequenas;
- nomear resultados em `lowerCamelCase`;
- ligar dependências de dados por `result_ref`;
- registrar dependências de controle quando necessárias;
- identificar informação obrigatória ausente;
- preservar valores literais fornecidos pelo usuário;
- permanecer independente de implementação shell.

## Entradas

`UserRequest.text`.

O `request_id` é interno e não pertence ao conteúdo fornecido pelo cliente.

## Saídas

`NormalizedRequest` com intenção, instrução canônica, tarefas, saída final, status e entradas ausentes.

## Interfaces e contratos

- [CTR-0001](../contratos/pipeline-protobuf.md)

## Restrições

O normalizador não gera Bash, não chama tools, não escolhe capability e não inventa informação.

**BLOCKED:** a forma final do contrato de dados depende de ADR-0009; a documentação anterior usava `StreamEncoding` na própria normalização.

## Critérios de aceite

- IDs e nomes de resultado são únicos.
- `result_ref` aponta apenas para resultados anteriores existentes.
- DAG é acíclico.
- `final_output_ref` existe quando o status é READY.
- MISSING_INFORMATION interrompe o pipeline.
- Nenhuma implementação shell aparece nas tarefas.

## Implementação relacionada

Referência histórica: `src/go/internal/pipeline/`. Não verificada nesta adequação documental.
