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
    +--> GeneratorToolRequests
    |       |
    |       +--> ai-bash-gen Tool Orchestrator
    |                 |
    |                 +--> get_capability
    |                 +--> generation-time MCP
    |
    v
GenerationPlan
    |
    v
05 validation                     [determinístico]
    |
    +--> valida grafo, contratos e versões
    +--> bash -n + ShellCheck
    |
    +--> Capability Publisher      [idempotente]
    |
    v
06 bash-output                    [determinístico]
    |
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
| 04 | [bash-generator](04_BASH_GENERATOR.md) | sim | `GeneratorTurnRequest` | `GeneratorTurnResult` / `GenerationPlan` |
| 05 | [validation](05_VALIDATION.md) | não | `ValidationRequest` | `ValidationResult` |
| 06 | [bash-output](06_BASH_OUTPUT.md) | não | geração validada | `BashArtifact` / arquivo `.sh` |

Referência comum: [Contratos Protobuf](PROTOBUF.md).

Schema canônico: [pipeline.proto](../../proto/ai_bash_gen/v1/pipeline.proto).

Visualização dos fluxos: [SEQUENCE_DIAGRAMS.md](SEQUENCE_DIAGRAMS.md).

Revisão de arquitetura atual: [../analysis/ARCHITECTURE_REVIEW_V2.md](../analysis/ARCHITECTURE_REVIEW_V2.md).

Histórico V1: [../analysis/ARCHITECTURE_REVIEW.md](../analysis/ARCHITECTURE_REVIEW.md).

## Diagnóstico por etapa no mesmo socket

A rota pública permanece única:

```text
/run/ai-bash-gen/routes/generate.sock
```

`GenerateRequest.target_stage` permite executar todos os pré-requisitos e interromper o processamento depois da etapa selecionada. Isso é usado pelo cliente para inspecionar a saída intermediária sem criar sockets adicionais.

Etapas suportadas:

```text
request-normalizer
normalized-request
search-capabilities
bash-generator
validation
bash-output
```

Exemplos com o cliente oficial:

```bash
ai-bash-gen-client --stage request-normalizer "diagnostique o serviço ssh"
ai-bash-gen-client --stage normalized-request "diagnostique o serviço ssh"
ai-bash-gen-client --stage search-capabilities "diagnostique o serviço ssh"
ai-bash-gen-client --stage bash-generator "diagnostique o serviço ssh"
ai-bash-gen-client --stage validation "diagnostique o serviço ssh"
ai-bash-gen-client --stage bash-output --out ./diagnostico.sh "diagnostique o serviço ssh"
```

Não existem rotas públicas separadas para as etapas. Os processos LLM internos usam sockets privados distintos para `request-normalizer` e `bash-generator`.

### Estado de implementação

O runtime já executa o `request-normalizer` real, valida separadamente a `NormalizedRequest` e executa a pesquisa PostgreSQL por requisição completa e por tarefa. O `bash-generator` recebe a `NormalizedRequest` e os candidatos encontrados.

A evolução para o `GenerationPlan` completo, `get_capability` sob demanda e materialização determinística descrita neste documento continua sendo o contrato arquitetural alvo. Enquanto esse tool loop não estiver concluído, o runtime do `bash-generator` ainda produz a fonte Bash diretamente e a etapa seguinte executa `bash -n`.

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

Uma capability composta pode substituir várias tarefas quando seus contratos estruturados de entrada e saída atenderem ao fluxo completo. Resultados encadeados usam `stdout -> stdin`; o `DataContract` valida tipo, campos e encoding.

## Regra de transporte

```text
entre componentes:
Protobuf binário

fronteira com LLM:
Protobuf Text Format (TextProto)
```

Nunca enviar Protobuf binário codificado em Base64 ao modelo.
