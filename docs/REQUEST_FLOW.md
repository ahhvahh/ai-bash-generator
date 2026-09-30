# Fluxo de Requisição

Este documento apresenta o pipeline geral do `ai-bash-gen`.

Cada etapa possui documentação própria:

- [REQUEST_NORMALIZER.md](REQUEST_NORMALIZER.md) — prompt e contrato do normalizador;
- [NORMALIZED_REQUEST.md](NORMALIZED_REQUEST.md) — grafo de tarefas e referências entre resultados;
- [SEARCH_CAPABILITIES.md](SEARCH_CAPABILITIES.md) — descoberta determinística no catálogo;
- [BASH_GENERATOR.md](BASH_GENERATOR.md) — prompt, composição e geração;
- [PROTOBUF_PIPELINE.md](PROTOBUF_PIPELINE.md) — regras de Protobuf binário e TextProto.

Os contratos canônicos estão em [../proto/ai_bash_gen/v1/pipeline.proto](../proto/ai_bash_gen/v1/pipeline.proto).

## Pipeline

```text
UserRequest
    |
    v
request-normalizer
    |
    v
NormalizedRequest
    |
    v
search_capabilities
    |
    v
candidatos resumidos
    |
    v
bash-generator
    |
    +--> get_capability(id), quando necessário
    |
    v
Capability / ScriptArtifact
    |
    +--> reutiliza capability existente
    |
    +--> ou gera nova capability parametrizada
    |
    v
validação
    |
    +--> nova capability válida -> catálogo
    |
    v
resposta ao cliente
```

## 1. Normalização

Um LLM pequeno converte a solicitação do usuário em uma `NormalizedRequest`.

A requisição é decomposta em pequenas tarefas, cada uma com uma saída nomeada. Resultados anteriores podem alimentar tarefas posteriores por `result_ref`.

Ele não gera código e não consulta MCP.

## 2. Pesquisa

O `ai-bash-gen` procura primeiro uma capability capaz de resolver a requisição completa e também candidatos para as tarefas individuais.

A busca usa:

- intent;
- canonical instruction;
- input description;
- output description.

O retorno de cada candidato contém somente:

- id;
- type;
- description;
- match instruction;
- input description;
- output description.

## 3. Escolha e detalhes

O `bash-generator` compara os candidatos.

Quando precisa avaliar ou utilizar um candidato, chama:

```text
get_capability(id)
```

Essa chamada registra um evento append-only em `capability_usage`.

## 4. Reutilização

Se uma capability atende ao requisito, o gerador utiliza a implementação existente e aplica os valores concretos presentes na `NormalizedRequest`.

## 5. Nova capability

Se não existir uma capability adequada, o gerador produz uma nova função reutilizável.

A função deve ser:

- genérica;
- parametrizada;
- independente dos valores específicos da requisição;
- documentada com entrada e saída;
- validada antes de entrar no catálogo.

Exemplo:

```text
User value:
~/ambiente

Reusable capability:
list_subdirectories(base_path)

Current invocation:
list_subdirectories "$HOME/ambiente"
```

## 6. Catálogo crescente

Com o tempo:

```text
requisições novas
      |
      v
capabilities reutilizadas
      |
      +--> menos código novo
      |
      +--> respostas mais previsíveis
      |
      +--> menor custo de inferência
```

O catálogo deve evoluir de forma incremental sem transformar operações triviais de Bash em capabilities desnecessárias.
