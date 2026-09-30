# 02 — NormalizedRequest

## Responsabilidade

`NormalizedRequest` é o contrato intermediário entre a interpretação da linguagem natural e a descoberta/geração de capabilities.

Ela descreve:

- objetivo global;
- pequenas tarefas;
- entradas literais;
- dependências entre tarefas;
- resultados nomeados;
- fluxo de dados entre resultados;
- saída final esperada.

Ela não descreve comandos Bash nem implementações.

## Contrato Protobuf

Definido em:

```text
../../proto/ai_bash_gen/v1/pipeline.proto
```

Estrutura principal:

```proto
message NormalizedRequest {
  string intent = 1;
  string canonical_instruction = 2;
  string input_description = 3;
  string output_description = 4;
  repeated NormalizedTask tasks = 5;
  string final_output_ref = 6;
}

message NormalizedTask {
  string id = 1;
  string instruction = 2;
  string input_description = 3;
  string output_description = 4;
  repeated TaskInput inputs = 5;
  TaskOutput output = 6;
  repeated string depends_on = 7;
}
```

## Modelo de processamento

Uma requisição composta deve formar um pequeno grafo de dados.

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

O resultado de uma tarefa deve ser referenciado pela próxima tarefa sem copiar o conteúdo.

```textproto
inputs {
  name: "source"
  type: "table"
  result_ref: "resultList"
}
```

## Campos globais

### `intent`

Identificador curto e estável da finalidade completa.

Exemplo:

```text
list_executable_files
```

### `canonical_instruction`

Descrição em inglês do objetivo completo, preferencialmente sem valores específicos.

Exemplo:

```text
List executable files with selected metadata and sorting.
```

### `input_description`

Resumo das entradas externas necessárias para cumprir o objetivo completo.

### `output_description`

Resumo da saída final.

Esses quatro campos podem ser usados para procurar uma capability composta que resolva toda a requisição.

## Tarefas

Cada `NormalizedTask` representa uma transformação pequena.

Exemplo:

```textproto
tasks {
  id: "filter_executables"
  instruction: "Keep executable files only."
  input_description: "Table containing file metadata."
  output_description: "Table containing executable files only."

  inputs {
    name: "source"
    type: "table"
    result_ref: "resultList"
  }

  output {
    name: "filteredList"
    type: "table"
    fields: "name"
    fields: "size"
    fields: "type"
  }

  depends_on: "list_files"
}
```

## Entradas

Uma entrada possui nome e tipo e recebe seu valor de uma das duas fontes:

### Literal

Valor fornecido pelo usuário:

```textproto
inputs {
  name: "path"
  type: "path"
  literal: "~/ambiente"
}
```

### Resultado anterior

Valor produzido por outra tarefa:

```textproto
inputs {
  name: "source"
  type: "table"
  result_ref: "resultList"
}
```

O campo `oneof source` do Protobuf impede que uma entrada seja simultaneamente literal e referência.

## Saídas

Toda tarefa deve possuir exatamente uma saída nomeada.

```textproto
output {
  name: "resultList"
  type: "table"
  fields: "name"
  fields: "size"
  fields: "type"
}
```

Nomes devem ser únicos dentro da requisição.

Convenção:

```text
lowerCamelCase
```

Exemplos:

```text
resultList
filteredList
sortedList
archiveFile
emailList
reportTable
```

## Compatibilidade entre tarefas

Antes de aceitar uma cadeia, a aplicação deve conferir se o tipo da saída anterior é compatível com a entrada seguinte.

Exemplo válido:

```text
list_files
output: table
        |
        v
filter_executables
input: table
```

Uma capability selecionada para uma tarefa deve possuir saída compatível com o contrato da tarefa, e não apenas descrição semanticamente semelhante.

## Capability composta

As tarefas são uma descrição lógica do problema. Elas não obrigam a execução em múltiplas funções.

Para:

```text
list_files
filter_executables
sort_by_size
```

o catálogo pode retornar uma única capability:

```text
list-executable-files-sorted-by-size
```

Se entrada e saída forem compatíveis com a requisição completa, o gerador pode substituir toda a cadeia por essa capability.

A decomposição continua sendo útil porque fornece fallback caso não exista uma implementação composta.

## Exemplo completo

```textproto
intent: "list_executable_files"
canonical_instruction: "List executable files with selected metadata and sorting."
input_description: "Directory path."
output_description: "Table containing executable files with name, size and type ordered by size descending."

tasks {
  id: "list_files"
  instruction: "List directory items with name, size and type."
  input_description: "Directory path."
  output_description: "Table containing name, size and type for each item."
  inputs {
    name: "path"
    type: "path"
    literal: "~/ambiente"
  }
  output {
    name: "resultList"
    type: "table"
    fields: "name"
    fields: "size"
    fields: "type"
  }
}

tasks {
  id: "filter_executables"
  instruction: "Keep executable files only."
  input_description: "Table containing file metadata."
  output_description: "Table containing executable files only."
  inputs {
    name: "source"
    type: "table"
    result_ref: "resultList"
  }
  output {
    name: "filteredList"
    type: "table"
    fields: "name"
    fields: "size"
    fields: "type"
  }
  depends_on: "list_files"
}

tasks {
  id: "sort_by_size"
  instruction: "Sort rows by size descending."
  input_description: "Table containing executable file metadata."
  output_description: "Table ordered by size descending."
  inputs {
    name: "source"
    type: "table"
    result_ref: "filteredList"
  }
  output {
    name: "sortedList"
    type: "table"
    fields: "name"
    fields: "size"
    fields: "type"
  }
  depends_on: "filter_executables"
}

final_output_ref: "sortedList"
```

## Representação para o LLM

O contrato canônico é Protobuf.

- entre componentes: Protobuf binário;
- entrada/saída textual do LLM: Protobuf Text Format;
- banco: estrutura própria do PostgreSQL;
- não usar base64 para enviar Protobuf binário ao LLM.

O TextProto deve omitir campos com valores padrão e qualquer metadado que a etapa atual não precise conhecer.

## Validações

A aplicação deve rejeitar uma `NormalizedRequest` quando:

- não houver tarefas;
- uma tarefa não possuir saída;
- houver resultados duplicados;
- `result_ref` apontar para resultado inexistente;
- houver referência a resultado futuro;
- houver ciclo;
- tipos forem incompatíveis;
- `final_output_ref` não existir;
- valores necessários tiverem sido inventados;
- tarefas contiverem implementação shell em vez de comportamento lógico.
