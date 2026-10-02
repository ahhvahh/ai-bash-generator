# Request Normalizer

![MOD](https://img.shields.io/badge/MOD-MOD--0001-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Transformar linguagem natural em uma `NormalizedRequest` estruturada, ordenada e independente de implementação.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [CTR-0001 — Protobuf do pipeline](../contratos/pipeline-protobuf.md)
- [PRM-0001 — Prompt do normalizador](../prompts/request-normalizer.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Responsabilidades

- decompor o objetivo em tasks pequenas e semanticamente independentes;
- emitir as tasks em ordem lógica de processamento;
- manter IDs únicos em `snake_case`;
- ligar dependências reais de dados por `result_ref`;
- permitir que um output tenha zero, um ou vários consumidores;
- não criar dependências entre tasks independentes;
- registrar dependências de controle por `depends_on` somente quando necessárias;
- representar definições de entrada e saída como objetos JSON válidos nos campos descritivos do contrato atual;
- identificar informação obrigatória ausente;
- preservar valores literais fornecidos pelo usuário;
- permanecer independente de Bash, capabilities, packages, databases e tools.

## Entradas

`UserRequest.text`.

O `request_id` é interno e não pertence ao conteúdo fornecido pelo cliente.

## Saídas

`NormalizedRequest` com intenção, instrução canônica, sequência de tasks, contratos de entrada e saída, saída final, status e entradas ausentes.

### Sequência

A sequência é determinada pela ordem do campo repetido `NormalizedRequest.tasks`. A ordem é significativa e deve ser preservada pelo normalizador e pelos consumidores.

A ordem não substitui o grafo de dependências. `result_ref` continua sendo a fonte de verdade para dependência de dados e `depends_on` para dependência exclusivamente de controle.

### Fan-out e outputs independentes

Um output não precisa ser consumido por outra task. Isso é válido quando ele representa um resultado solicitado pelo usuário ou um resultado intermediário independente.

O mesmo output também pode alimentar múltiplas tasks posteriores. Cada consumidor aponta para o mesmo `result_ref`; o conteúdo não deve ser duplicado.

Quando vários outputs precisam compor a resposta final, deve existir uma task final de agregação lógica.

## Interfaces e contratos

- [CTR-0001](../contratos/pipeline-protobuf.md)
- [PRM-0001](../prompts/request-normalizer.md)

## Restrições

O normalizador não gera Bash, não chama tools, não escolhe capability e não inventa informação.

No contrato atual, `input_description` e `output_description` são strings. Até uma evolução do Protobuf, essas strings transportam um objeto JSON compacto e válido, em vez de prosa livre.

## Critérios de aceite

- IDs e nomes de resultado são únicos.
- A ordem de `tasks` representa a sequência lógica.
- `result_ref` aponta somente para resultados anteriores existentes.
- Um output pode ter zero, um ou vários consumidores.
- O DAG de dependências é acíclico.
- `final_output_ref` existe quando o status é READY.
- `MISSING_INFORMATION` interrompe o pipeline antes da geração.
- As definições JSON de entrada e saída são válidas e coerentes com `TaskInput`/`TaskOutput`.
- Nenhuma implementação shell aparece nas tasks.

## Implementação relacionada

A implementação de referência do normalizador está em `src/go/internal/pipeline/runner.go` no commit `main@a734af859d800487b51b5136d5772397dc12ffc6`. O prompt ainda está embutido no binário e deve ser externalizado conforme OPS-0001.
