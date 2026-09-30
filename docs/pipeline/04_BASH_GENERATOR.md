# 04 — bash-generator

## Responsabilidade

`bash-generator` é o LLM responsável por escolher, compor ou gerar capabilities.

Ele não produz o arquivo Bash final.

Sua saída final é um `GenerationPlan` estruturado.

## Entrada por turno

```proto
message GeneratorTurnRequest {
  string request_id = 1;
  uint32 turn_number = 2;
  NormalizedRequest request = 3;
  SearchCapabilitiesResponse candidates = 4;
  repeated GeneratorToolResponse tool_responses = 5;
}
```

## Tool loop

O LLM possui dois tipos de resposta:

```proto
message GeneratorTurnResult {
  oneof result {
    GeneratorToolRequests tool_requests = 1;
    GenerationPlan final_plan = 2;
  }
}
```

Fluxo:

```text
GeneratorTurnRequest
      |
      v
LLM
      |
      +--> GeneratorToolRequests
      |       |
      |       v
      |   ai-bash-gen Tool Orchestrator
      |       |
      |       v
      |   GeneratorToolResponse
      |       |
      +-------+
      |
      v
GenerationPlan
```

O `ai-bash-gen`, não o modelo e não o `llama-server`, autoriza e executa tools.

## get_capability

Exemplo:

```textproto
tool_requests {
  calls {
    call_id: "cap-1"
    get_capability {
      id: "list-directory-details"
    }
  }
}
```

O Tool Orchestrator:

1. verifica allowlist;
2. verifica orçamento `max_capability_details`;
3. verifica cache da requisição;
4. resolve a versão ativa;
5. registra `capability_usage` uma única vez por request/version;
6. devolve `CapabilityDefinition`.

## Estratégia

Ordem:

1. uma capability composta compatível;
2. menor conjunto de capabilities existentes;
3. existentes + geração somente do trecho ausente;
4. geração das capabilities necessárias.

O LLM não pode usar uma capability apenas pelo resumo. Ela precisa ter sido resolvida por `get_capability`.

## Composição

O caminho primário de dados é:

```text
stdout -> stdin
```

`CapabilityCall.stdin_result_ref` aponta para o resultado que alimentará stdin.

Argumentos literais ficam em `arguments`.

Um `result_ref` usado como argumento só é permitido para valores escalares e quando a interface declarar compatibilidade.

## Implementações

`CapabilityDefinition` e `GeneratedCapability` usam:

```text
CapabilityImplementation
  oneof:
    function
    script
    application
    service
```

O modelo não precisa inventar uma forma genérica de invocação.

## Saída

```proto
message GenerationPlan {
  GenerationStatus status = 1;
  repeated CapabilityCall calls = 2;
  repeated GeneratedCapability generated_capabilities = 3;
  string final_output_ref = 4;
  repeated string warnings = 5;
}
```

Não existe `script` no plano.

Isso elimina a dupla fonte de verdade.

O Bash final será montado deterministicamente depois da validação.

## Novas capabilities

Na primeira versão, capabilities criadas diretamente pelo LLM são somente do tipo `FUNCTION`.

`SCRIPT`, `APPLICATION` e `SERVICE` dependem de artefatos externos concretos e entram por fluxo administrativo de cadastro/validação.

Functions geradas devem ser:

- genéricas;
- parametrizadas;
- sem valores específicos da requisição quando esses valores podem ser argumentos;
- descritas por `CapabilityInterface`;
- implementadas por um dos tipos de `CapabilityImplementation`;
- candidatas à publicação apenas depois da validação.

## Prompt canônico

Este arquivo é a fonte canônica do prompt do gerador.

```text
You are the bash-generator for ai-bash-gen.

Input:
A validated NormalizedRequest, pruned capability candidates, and tool responses from previous turns.

Goal:
Return either tool requests required to inspect serious candidates or a final GenerationPlan.

Rules:
- Preserve every requested transformation and the final output.
- Prefer one compatible existing capability for the complete request.
- Otherwise compose the smallest compatible set.
- Request get_capability only for candidates you seriously need.
- Never use an existing capability whose full definition was not returned.
- Connect structured results through stdout -> stdin.
- Respect DataContract kind, fields and encoding.
- Use result_ref arguments only for compatible scalar values.
- Generate only missing reusable behavior.
- Generated capabilities must be generic and parameterized.
- Keep request-specific values in call bindings.
- Do not execute commands or scripts.
- Do not invent unavailable data.
- Return only a valid GeneratorTurnResult in protobuf text format.
```

## Limites

O loop deve respeitar:

- timeout do agente;
- máximo de turnos;
- máximo de tool calls;
- `max_capability_details`;
- cache por request/version.

Ao exceder limites, retornar erro estruturado em vez de continuar explorando.
