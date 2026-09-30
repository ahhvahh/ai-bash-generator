# 01 — request-normalizer

## Responsabilidade

`request-normalizer` é a primeira etapa com LLM.

Recebe linguagem natural e produz uma `NormalizedRequest` estruturada.

Ele:

- separa o objetivo em pequenas tarefas;
- nomeia os resultados;
- liga resultados anteriores por `result_ref`;
- descreve tipos estruturados;
- identifica entradas obrigatórias ausentes.

Ele não:

- gera Bash;
- escolhe comandos;
- consulta MCP;
- escolhe capabilities;
- executa ações.

## Entrada

```proto
message UserRequest {
  string text = 1;
}
```

Visão TextProto. O `request_id` interno é criado pelo `ai-bash-gen` depois que a requisição é aceita e não é controlado pelo cliente:

```textproto
text: "liste os itens de ~/ambiente com nome, tamanho e tipo; mantenha apenas executáveis e ordene por tamanho"
```

## Saída

```proto
message NormalizedRequest {
  string intent = 1;
  string canonical_instruction = 2;
  string input_description = 3;
  string output_description = 4;
  repeated NormalizedTask tasks = 5;
  string final_output_ref = 6;
  NormalizationStatus status = 7;
  repeated MissingInput missing_inputs = 8;
}
```

## Decomposição

Exemplo:

```text
list_files
   |
   | resultList
   v
filter_executables
   |
   | filteredList
   v
sort_by_size
   |
   | sortedList
   v
final output
```

Cada tarefa deve:

- executar um objetivo pequeno;
- possuir uma saída nomeada;
- usar `result_ref` quando consumir resultado anterior;
- descrever entrada e saída em inglês;
- permanecer independente da implementação Bash.

## Tipos

O normalizador utiliza `DataContract`, não strings livres.

Exemplo de saída tabular:

```textproto
output {
  name: "resultList"

  contract {
    kind: DATA_KIND_TABLE
    encoding: STREAM_ENCODING_JSON_LINES

    fields { name: "name" kind: DATA_KIND_TEXT required: true }
    fields { name: "size" kind: DATA_KIND_INTEGER required: true }
    fields { name: "type" kind: DATA_KIND_TEXT required: true }
  }
}
```

O normalizador descreve o contrato lógico. Ele não escolhe comandos.

## Informação ausente

Se uma entrada essencial não foi fornecida, não inventar valor.

Exemplo:

```textproto
status: NORMALIZATION_STATUS_MISSING_INFORMATION

missing_inputs {
  task_id: "copy_files"
  name: "destination"
  description: "Destination directory."
  contract {
    kind: DATA_KIND_PATH
    encoding: STREAM_ENCODING_TEXT_UTF8
  }
}
```

O pipeline deve parar nessa condição.

## Prompt canônico

Este arquivo é a fonte canônica do prompt do normalizador.

```text
You normalize user requests for ai-bash-gen.

Return a NormalizedRequest.

Rules:
- Write semantic instructions and descriptions in English.
- Preserve literal values exactly as provided by the user.
- Split independent transformations into small logical tasks.
- Each task has exactly one named output.
- Use lowerCamelCase result names.
- Reference previous outputs using result_ref; do not copy their content.
- Use structured DataContract values.
- Keep tasks implementation-independent.
- Do not choose shell commands or capabilities.
- Do not call tools.
- Do not execute anything.
- Do not invent missing values.
- If required information is missing, set MISSING_INFORMATION and describe it in missing_inputs.
- canonical_instruction describes the complete goal without concrete values when possible.
- final_output_ref references the requested final result.
- Return only valid NormalizedRequest protobuf text.
```

## Validação após o LLM

A aplicação deve validar:

1. TextProto válido;
2. status consistente;
3. IDs únicos;
4. nomes de resultado únicos;
5. `result_ref` válido;
6. contratos estruturados válidos;
7. DAG sem ciclos;
8. `final_output_ref` válido;
9. ausência de valores inventados;
10. ausência de implementação shell.

Somente `NORMALIZATION_STATUS_READY` segue para `search_capabilities`.
