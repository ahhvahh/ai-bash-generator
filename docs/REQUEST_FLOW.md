# Fluxo de Requisição

Este documento apresenta o pipeline geral do `ai-bash-gen`.

A especificação detalhada da normalização está em [NORMALIZED_REQUEST.md](NORMALIZED_REQUEST.md).

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

Ele não gera código e não consulta MCP.

## 2. Pesquisa

O `ai-bash-gen` consulta o Capability Catalog usando:

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
