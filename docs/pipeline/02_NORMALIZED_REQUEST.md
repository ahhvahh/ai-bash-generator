# 02 — NormalizedRequest

## Responsabilidade

`NormalizedRequest` é o contrato intermediário entre a interpretação da linguagem natural e a descoberta/geração de capabilities.

Ela descreve:

- objetivo global;
- pequenas tarefas;
- entradas literais;
- dependências de dados;
- dependências de controle;
- resultados nomeados;
- tipos estruturados;
- saída final esperada;
- informações obrigatórias ausentes.

Ela não descreve comandos Bash nem implementações.

## Contrato principal

Definido em:

```text
../../proto/ai_bash_gen/v1/pipeline.proto
```

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

## Status da normalização

```text
READY
MISSING_INFORMATION
UNSUPPORTED
```

Quando faltar uma entrada obrigatória:

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

Nesse caso o pipeline deve parar antes de `search_capabilities`.

## Tipos estruturados

Tipos não são mais strings livres.

```text
DataKind
DataContract
FieldSchema
StreamEncoding
```

Exemplo de tabela:

```textproto
contract {
  kind: DATA_KIND_TABLE
  encoding: STREAM_ENCODING_JSON_LINES

  fields {
    name: "name"
    kind: DATA_KIND_TEXT
    required: true
  }

  fields {
    name: "size"
    kind: DATA_KIND_INTEGER
    required: true
  }

  fields {
    name: "type"
    kind: DATA_KIND_TEXT
    required: true
  }
}
```

Isso permite à aplicação comparar contratos sem depender da interpretação textual do LLM.

## Fluxo de dados

Uma requisição composta forma um grafo lógico:

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

`result_ref` cria dependência de dados automaticamente.

```textproto
inputs {
  name: "source"
  contract {
    kind: DATA_KIND_TABLE
    encoding: STREAM_ENCODING_JSON_LINES
  }
  result_ref: "resultList"
}
```

## depends_on

`depends_on` existe apenas para dependência de controle quando não há passagem de dados.

Regra:

```text
result_ref  -> dependência de dados
depends_on  -> dependência de controle
```

A aplicação deriva o DAG final e rejeita inconsistências ou ciclos.

## ABI de runtime

Para resultados encadeados:

```text
producer stdout -> consumer stdin
```

`result_ref` representa logicamente esse stream.

O conteúdo do stream deve obedecer ao `DataContract`:

- tipo;
- campos;
- encoding.

### Restrição inicial

Uma capability possui um único `stdin`.

Portanto, na versão inicial:

- cada chamada pode possuir no máximo um resultado estruturado ligado ao `stdin`;
- valores escalares adicionais podem ser argumentos;
- fan-out/fan-in de streams exige capability explícita de `tee`, merge/join ou materialização intermediária;
- o assembler não deve inventar branching implícito.

## Saídas

Toda tarefa possui uma saída nomeada:

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

Nomes seguem `lowerCamelCase`.

## Capability composta

A decomposição lógica não obriga múltiplas funções.

Se uma capability ativa possuir interface compatível com o objetivo completo, ela pode substituir várias tarefas.

A compatibilidade final é calculada deterministicamente pelo `ai-bash-gen`.

## Validações

Rejeitar quando:

- status inválido;
- status READY com `missing_inputs`;
- não houver tarefas quando READY;
- IDs forem duplicados;
- resultados forem duplicados;
- `result_ref` apontar para resultado inexistente ou futuro;
- houver ciclo;
- tipo/encoding forem incompatíveis;
- houver mais de um stream estruturado concorrendo pelo mesmo stdin;
- `final_output_ref` não existir;
- valores necessários forem inventados;
- tarefas contiverem implementação shell.
