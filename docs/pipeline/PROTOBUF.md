# Contratos Protobuf do pipeline

## Objetivo

O Protobuf é o contrato canônico do pipeline.

Schema:

```text
../../proto/ai_bash_gen/v1/pipeline.proto
```

## Representações

```text
entre componentes
    Protobuf binário

fronteira ai-bash-gen <-> LLM
    Protobuf Text Format
```

Não enviar Protobuf binário em Base64 ao modelo.

## Tipos estruturados

A composição utiliza:

```text
DataKind
DataContract
FieldSchema
StreamEncoding
CapabilityInterface
ParameterContract
```

Exemplo:

```textproto
contract {
  kind: DATA_KIND_TABLE
  encoding: STREAM_ENCODING_JSON_LINES

  fields { name: "name" kind: DATA_KIND_TEXT required: true }
  fields { name: "size" kind: DATA_KIND_INTEGER required: true }
}
```

Isso permite validação determinística entre stdout e stdin.

## Turnos do gerador

O gerador não é uma chamada única.

```text
GeneratorTurnRequest
      |
      v
GeneratorTurnResult
      |
      +--> GeneratorToolRequests
      |        |
      |        v
      |    GeneratorToolResponse
      |        |
      +--------+
      |
      v
GenerationPlan
```

Tools de catálogo e MCPs generation-time passam sempre pelo Tool Orchestrator do `ai-bash-gen`.

## Entrada do LLM

A aplicação cria uma visão mínima da mensagem.

Em Go, conceitualmente:

```go
text, err := prototext.MarshalOptions{
    Multiline: true,
}.Marshal(message)
```

Campos internos já processados deterministicamente podem ser omitidos da visão entregue ao modelo.

## Saída do LLM

```text
LLM TextProto
     |
     v
prototext.Unmarshal
     |
     v
protobuf message
     |
     v
semantic validation
```

Estrutura Protobuf não implica autorização ou correção semântica.

## Economia de tokens

Protobuf binário reduz IPC e armazenamento.

TextProto não possui economia de tokens comprovada.

A estratégia atual reduz contexto por:

1. divisão do pipeline em etapas;
2. `result_ref` em vez de copiar resultados;
3. candidate budget;
4. deterministic pruning antes do LLM;
5. resumo de candidates;
6. detalhes somente por `get_capability`;
7. cache por request/version;
8. omissão de telemetria e metadados operacionais.

A comparação TextProto x JSON compacto permanece sujeita a benchmark com o tokenizer real do modelo.

## Result refs

Exemplo:

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

No plano de execução, o stream principal é materializado como:

```text
producer stdout -> consumer stdin
```

Não é necessário copiar o conteúdo de `resultList` para o prompt ou para uma variável Bash.

## Tool payloads de MCP

MCPs generation-time genéricos utilizam:

```text
ToolPayload
  schema
  textproto
```

`schema` identifica o tipo Protobuf específico do MCP.

A string TextProto existe apenas na fronteira com o LLM; processos internos podem usar a mensagem Protobuf concreta correspondente.

## Segurança

Toda resposta do LLM passa por:

- parsing;
- validação do schema;
- validação semântica;
- allowlist;
- limites;
- política;
- validação de contratos.

Protobuf garante estrutura. Não garante confiança.
