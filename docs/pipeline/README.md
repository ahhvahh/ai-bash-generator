# Pipeline de geração

Esta pasta documenta, em ordem de execução, o processamento completo de uma solicitação: do texto original do usuário até a criação do arquivo Bash final.

## Ordem

```text
UserRequest
    |
    v
01 request-normalizer             [LLM]
    |
    v
02 NormalizedRequest              [contrato/validação]
    |
    v
03 search_capabilities            [PostgreSQL, sem LLM]
    |
    v
04 bash-generator                 [LLM]
    |
    +--> get_capability(id)
    |       |
    |       +--> append capability_usage
    |
    v
05 validation                     [determinístico]
    |
    +--> valida GenerationResult
    +--> valida Bash
    +--> valida novas capabilities
    |
    v
06 bash-output                    [determinístico]
    |
    +--> persiste capabilities aprovadas
    +--> monta arquivo .sh
    |
    v
arquivo Bash final
```

## Documentos

| Ordem | Etapa | Usa LLM | Entrada | Saída |
|---|---|---:|---|---|
| 01 | [request-normalizer](01_REQUEST_NORMALIZER.md) | sim | `UserRequest` | `NormalizedRequest` |
| 02 | [NormalizedRequest](02_NORMALIZED_REQUEST.md) | não | TextProto do normalizador | objeto validado |
| 03 | [search_capabilities](03_SEARCH_CAPABILITIES.md) | não | `SearchCapabilitiesRequest` | `SearchCapabilitiesResponse` |
| 04 | [bash-generator](04_BASH_GENERATOR.md) | sim | `GenerationRequest` | `GenerationResult` |
| 05 | [validation](05_VALIDATION.md) | não | `GenerationResult` | `ValidationResult` |
| 06 | [bash-output](06_BASH_OUTPUT.md) | não | geração validada | `BashArtifact` / arquivo `.sh` |

Referência comum: [Contratos Protobuf](PROTOBUF.md).

Schema canônico: [pipeline.proto](../../proto/ai_bash_gen/v1/pipeline.proto).

Visualização dos fluxos: [SEQUENCE_DIAGRAMS.md](SEQUENCE_DIAGRAMS.md).

Problemas e riscos de arquitetura: [../analysis/ARCHITECTURE_REVIEW.md](../analysis/ARCHITECTURE_REVIEW.md).

## Princípio

Os LLMs ficam restritos às etapas que realmente exigem interpretação ou geração:

```text
LLM:
01 request-normalizer
04 bash-generator

Determinístico:
02 validação da NormalizedRequest
03 pesquisa PostgreSQL
05 validação da geração
06 materialização do arquivo
```

Isso reduz tokens, latência e comportamento não determinístico.

## Encadeamento de dados

Uma requisição composta é dividida em pequenas tarefas:

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

Uma capability composta pode substituir várias tarefas quando seus contratos de entrada e saída atenderem ao fluxo completo.

## Regra de transporte

```text
entre componentes:
Protobuf binário

fronteira com LLM:
Protobuf Text Format (TextProto)
```

Nunca enviar Protobuf binário codificado em Base64 ao modelo.
