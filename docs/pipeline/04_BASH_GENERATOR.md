# 04 — bash-generator

## Responsabilidade

`bash-generator` é a etapa principal de composição e geração.

Ele recebe:

- a `NormalizedRequest`;
- candidatos encontrados por `search_capabilities`;
- detalhes das capabilities solicitadas por `get_capability`.

Ele decide se deve:

1. reutilizar uma capability composta;
2. combinar várias capabilities;
3. reutilizar algumas e gerar outras;
4. gerar uma nova capability parametrizada quando não houver alternativa adequada.

O resultado final deve preservar o fluxo de resultados nomeados da `NormalizedRequest`.

## Entrada

Contrato:

```proto
message GenerationRequest {
  NormalizedRequest request = 1;
  SearchCapabilitiesResponse candidates = 2;
  repeated CapabilityDefinition capability_details = 3;
}
```

Na primeira interação, `capability_details` pode estar vazio.

O modelo pode solicitar detalhes usando:

```proto
message CapabilityDetailRequest {
  string id = 1;
}
```

Cada `get_capability(id)`:

1. registra um append em `capability_usage`;
2. carrega a definição completa;
3. entrega ao modelo uma `CapabilityDefinition` compacta.

## Estratégia de composição

O gerador deve avaliar nesta ordem:

### 1. Capability composta

Se uma única capability satisfizer o objetivo completo, entrada e saída:

```text
NormalizedRequest
        |
        v
one capability
        |
        v
final result
```

ela deve ser preferida a uma cadeia maior.

### 2. Composição

Se nenhuma capability resolver tudo:

```text
capability A
   |
   | resultList
   v
capability B
   |
   | filteredList
   v
capability C
   |
   | sortedList
   v
final result
```

A saída de cada chamada deve ser compatível com a entrada da próxima.

### 3. Geração parcial

Se A e C existirem, mas B não:

```text
existing A
   |
   v
generated B
   |
   v
existing C
```

gerar somente a parte ausente.

### 4. Geração completa

Se nenhuma capability adequada existir, gerar funções novas, reutilizáveis e parametrizadas.

## Regras para novas capabilities

Uma função gerada não deve conter valores específicos da requisição quando esses valores podem ser parâmetros.

Evitar:

```bash
find ~/ambiente ...
```

Preferir:

```bash
list_directory_details() {
    local path="$1"
    ...
}
```

A invocação atual é separada:

```bash
list_directory_details "$HOME/ambiente"
```

Toda capability nova deve possuir:

- ID;
- descrição;
- match instruction;
- descrição da entrada;
- descrição da saída;
- nome da função;
- contrato de entrada;
- contrato de saída;
- implementação;
- dependências.

Ela entra inicialmente como candidata e só pode ser persistida como ativa após validação e deduplicação.

## Prompt de sistema

Prompt inicial recomendado:

```text
You are the bash-generator for ai-bash-gen.

Your input is a validated NormalizedRequest plus capability candidates and, when requested, capability definitions.

Goal:
Produce the smallest correct reusable implementation for the requested behavior.

Rules:
- Preserve the semantics of every task and the final output.
- Prefer one existing capability that satisfies the complete request when its input and output contracts are compatible.
- Otherwise compose the smallest set of compatible capabilities.
- Request get_capability only for candidates you seriously need to evaluate or use.
- Never assume details that were not returned by get_capability.
- A result_ref is the output of a previous task or capability call.
- Preserve named data flow between calls.
- Verify output/input compatibility before connecting capabilities.
- If an adequate capability does not exist, generate only the missing reusable function.
- Generated functions must be generic and parameterized.
- Do not hard-code request-specific values into reusable functions.
- Keep request-specific values in call arguments.
- Do not execute commands or scripts.
- Do not invent unavailable external data.
- Do not silently remove requested fields, filters, ordering or transformations.
- Return only a valid GenerationResult in protobuf text format.
```

## Exemplo de entrada para o LLM

Visão TextProto compacta:

```textproto
request {
  intent: "list_executable_files"
  canonical_instruction: "List executable files with selected metadata and sorting."
  input_description: "Directory path."
  output_description: "Table containing executable files with name, size and type ordered by size descending."

  tasks {
    id: "list_files"
    instruction: "List directory items with name, size and type."
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
}

candidates {
  composite_candidates {
    id: "list-executable-files"
    type: CAPABILITY_TYPE_FUNCTION
    description: "List executable directory items with metadata and sorting."
    match_instruction: "List executable files with selected metadata and sorting."
    input_description: "Directory path, selected fields and sort options."
    output_description: "Table containing matching files with selected fields."
  }
}
```

O modelo pode então solicitar:

```textproto
id: "list-executable-files"
```

para `get_capability`.

## Saída

```proto
message GenerationResult {
  GenerationStatus status = 1;
  repeated CapabilityCall calls = 2;
  repeated GeneratedCapability generated_capabilities = 3;
  string script = 4;
  string final_output_ref = 5;
  repeated string warnings = 6;
}
```

Exemplo usando uma capability composta:

```textproto
status: GENERATION_STATUS_READY

calls {
  task_id: "complete_request"
  capability_id: "list-executable-files"
  function_name: "list_executable_files"

  arguments {
    name: "path"
    literal: "~/ambiente"
  }

  output_ref: "sortedList"
}

script: "#!/usr/bin/env bash\n..."
final_output_ref: "sortedList"
```

## Exemplo com composição

```textproto
status: GENERATION_STATUS_READY

calls {
  task_id: "list_files"
  capability_id: "list-directory-details"
  function_name: "list_directory_details"
  arguments {
    name: "path"
    literal: "~/ambiente"
  }
  output_ref: "resultList"
}

calls {
  task_id: "filter_executables"
  capability_id: "filter-executable-rows"
  function_name: "filter_executable_rows"
  arguments {
    name: "source"
    result_ref: "resultList"
  }
  output_ref: "filteredList"
}

calls {
  task_id: "sort_by_size"
  capability_id: "sort-table"
  function_name: "sort_table"
  arguments {
    name: "source"
    result_ref: "filteredList"
  }
  arguments {
    name: "field"
    literal: "size"
  }
  arguments {
    name: "order"
    literal: "desc"
  }
  output_ref: "sortedList"
}

final_output_ref: "sortedList"
```

## Status

Valores:

```text
READY
MISSING_INFORMATION
MISSING_CAPABILITY
UNSUPPORTED
```

O modelo não deve produzir um script aparentemente funcional quando faltar uma capacidade externa essencial.

## Validação posterior

Antes de retornar ao cliente:

- validar TextProto;
- validar referências de resultados;
- validar contratos;
- validar IDs de capabilities;
- validar que detalhes foram carregados antes do uso;
- validar Bash sintaticamente;
- validar dependências permitidas;
- validar novas capabilities;
- deduplicar novas capabilities;
- rejeitar código que viole políticas do serviço.

A aplicação, e não o LLM, é responsável pela decisão final de persistir uma nova capability.
