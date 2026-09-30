# request-normalizer

## Responsabilidade

`request-normalizer` é a primeira etapa com LLM.

Ele recebe linguagem natural e produz uma `NormalizedRequest` estruturada.

O agente deve decompor a solicitação em pequenas tarefas reutilizáveis e encadeáveis.

Ele não:

- gera Bash;
- escolhe comandos;
- consulta MCP;
- escolhe capabilities;
- executa qualquer ação.

## Entrada canônica

Contrato Protobuf:

```proto
message UserRequest {
  string text = 1;
}
```

Entre componentes do `ai-bash-gen`, a mensagem pode trafegar em Protobuf binário.

Na fronteira com o LLM, o adaptador deve renderizar somente o conteúdo necessário em Protobuf Text Format.

Exemplo:

```textproto
text: "liste os itens da pasta ~/ambiente mostrando nome, tamanho e tipo; mantenha apenas executáveis e ordene por tamanho"
```

## Saída canônica

```proto
message NormalizedRequest {
  string intent = 1;
  string canonical_instruction = 2;
  string input_description = 3;
  string output_description = 4;
  repeated NormalizedTask tasks = 5;
  string final_output_ref = 6;
}
```

A especificação completa está em [NORMALIZED_REQUEST.md](NORMALIZED_REQUEST.md).

## Regras de decomposição

A solicitação deve ser dividida em tarefas pequenas quando existirem transformações logicamente independentes.

Exemplo:

```text
listar arquivos
   |
   v
resultList
   |
   v
filtrar executáveis
   |
   v
filteredList
   |
   v
ordenar por tamanho
   |
   v
sortedList
```

Cada tarefa deve:

- executar um objetivo pequeno;
- declarar claramente sua entrada;
- produzir exatamente um resultado nomeado;
- usar resultados anteriores por referência;
- descrever entrada e saída em inglês;
- permanecer independente de uma implementação Bash específica.

Resultados devem usar nomes curtos em `lowerCamelCase`.

Exemplos:

```text
resultList
filteredList
sortedList
emailList
archiveFile
```

Referências são armazenadas sem copiar o conteúdo:

```textproto
inputs {
  name: "source"
  type: "table"
  result_ref: "resultList"
}
```

## Prompt de sistema

Prompt inicial recomendado:

```text
You normalize user requests for ai-bash-gen.

Convert the user's request into a NormalizedRequest.

Rules:
- Write semantic instructions and descriptions in English.
- Preserve literal values exactly as provided by the user.
- Split the request into small logical tasks when the work contains independent transformations.
- Each task must have one named output.
- Use lowerCamelCase output names.
- When a task consumes a previous result, reference that result by name instead of copying it.
- Keep tasks implementation-independent.
- Do not choose Bash commands.
- Do not choose capabilities.
- Do not call tools.
- Do not execute anything.
- Do not invent missing values.
- canonical_instruction describes the complete user goal without concrete values when possible.
- task instruction describes only that task.
- input_description describes what the task accepts.
- output_description describes what the task produces.
- processing belongs in task decomposition, not shell syntax.
- final_output_ref must reference the final task output.
- Return only a valid NormalizedRequest in protobuf text format.
```

## Exemplo

Entrada:

```textproto
text: "liste os arquivos de ~/ambiente com nome, tamanho e tipo, mantenha apenas executáveis e ordene do maior para o menor"
```

Saída esperada:

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

## Validação após o LLM

Antes de seguir para a próxima etapa, o `ai-bash-gen` deve validar:

1. o TextProto pode ser convertido para `NormalizedRequest`;
2. todos os IDs de tarefa são únicos;
3. todos os nomes de resultado são únicos;
4. cada `result_ref` referencia uma saída anterior;
5. `depends_on` referencia tarefas existentes;
6. não existem ciclos;
7. `final_output_ref` existe;
8. nenhum comando shell aparece como implementação da tarefa;
9. valores concretos não foram inventados.

Se a estrutura for inválida, a aplicação deve rejeitar ou solicitar uma única correção estruturada ao modelo.
