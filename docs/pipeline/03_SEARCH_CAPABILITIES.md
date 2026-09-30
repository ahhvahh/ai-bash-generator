# 03 — search_capabilities

## Responsabilidade

`search_capabilities` recebe uma `NormalizedRequest` validada e procura no PostgreSQL capabilities que possam resolver:

1. a requisição completa; ou
2. cada tarefa individualmente.

Esta etapa deve ser determinística e não precisa de LLM.

Por isso ela não possui prompt de sistema.

## Objetivo

Reduzir o trabalho do `bash-generator`.

A busca deve oferecer poucos candidatos e respostas curtas, sem carregar código-fonte ou contratos detalhados.

## Entrada

```proto
message SearchCapabilitiesRequest {
  NormalizedRequest request = 1;
  uint32 limit = 2;
}
```

O valor de `limit` deve ser pequeno. Valor inicial sugerido:

```text
5
```

## Estratégia

### 1. Busca composta

Primeiro pesquisar uma capability que possa atender a requisição completa usando:

- `intent`;
- `canonical_instruction`;
- `input_description`;
- `output_description`.

Exemplo:

```text
List executable files with selected metadata and sorting.
```

Pode encontrar:

```text
list-executable-files-sorted-by-size
```

Se uma capability composta for adequada, o gerador poderá substituir várias tarefas por uma única chamada.

### 2. Busca por tarefa

Também pesquisar candidatos para cada tarefa.

Exemplo:

```text
list_files
filter_executables
sort_by_size
```

Isso fornece fallback quando nenhuma capability composta atende ao fluxo completo.

## Saída

```proto
message SearchCapabilitiesResponse {
  repeated CapabilityCandidate composite_candidates = 1;
  repeated TaskCandidates task_candidates = 2;
}
```

Cada candidato contém somente:

```proto
message CapabilityCandidate {
  string id = 1;
  CapabilityType type = 2;
  string description = 3;
  string match_instruction = 4;
  string input_description = 5;
  string output_description = 6;
}
```

## Exemplo em TextProto

```textproto
composite_candidates {
  id: "list-executable-files"
  type: CAPABILITY_TYPE_FUNCTION
  description: "List executable directory items with metadata and sorting."
  match_instruction: "List executable files with selected metadata and sorting."
  input_description: "Directory path, selected fields and sort options."
  output_description: "Table containing matching files with selected fields."
}

task_candidates {
  task_id: "list_files"
  candidates {
    id: "list-directory-details"
    type: CAPABILITY_TYPE_FUNCTION
    description: "List directory items with selectable metadata."
    match_instruction: "List directory items with selected metadata."
    input_description: "Directory path and selected fields."
    output_description: "Table containing one row per directory item."
  }
}

task_candidates {
  task_id: "filter_executables"
  candidates {
    id: "filter-executable-rows"
    type: CAPABILITY_TYPE_FUNCTION
    description: "Keep executable entries from a file metadata table."
    match_instruction: "Filter file metadata to executable entries."
    input_description: "Table containing file metadata."
    output_description: "Table containing executable entries only."
  }
}
```

## Dados que não devem ser retornados

A pesquisa não retorna:

- código;
- caminho de executável;
- dependências;
- versão;
- risco;
- complexidade;
- contador de uso;
- timestamps;
- contrato detalhado.

Esses dados são recuperados somente por `get_capability`.

## Seleção

`search_capabilities` não escolhe o vencedor.

Ele apenas entrega candidatos.

O `bash-generator` deve comparar:

```text
objective
input compatibility
output compatibility
composition cost
```

A preferência é:

```text
1 capability que resolve o fluxo completo
        >
menor conjunto de capabilities compatíveis
        >
geração de nova capability
```

desde que a opção escolhida preserve exatamente o comportamento solicitado.

## PostgreSQL

A pesquisa usa a tabela pequena `capability`.

Campos retornáveis:

```text
capability_key
type
description
match_instruction
input_description
output_description
```

A primeira filtragem pode combinar correspondência exata de `intent` e Full Text Search.

A aplicação deve executar uma consulta para a requisição completa e consultas por tarefa somente quando necessário.

## Registro de uso

`search_capabilities` não registra uso.

Somente:

```text
get_capability(id)
```

gera append em:

```text
capability_usage
```

porque é nesse momento que o agente solicita o conteúdo completo de uma capability.

## Limites

Regras iniciais:

- máximo de 5 candidatos compostos;
- máximo de 5 candidatos por tarefa;
- nenhuma repetição do mesmo ID dentro do mesmo conjunto;
- candidatos desabilitados nunca são retornados;
- resultados vazios são válidos.

## Protobuf e LLM

A saída canônica desta etapa é Protobuf.

O `bash-generator` recebe uma visão TextProto compacta contendo apenas os candidatos relevantes.

O binário Protobuf não deve ser codificado em base64 para inclusão no prompt.
