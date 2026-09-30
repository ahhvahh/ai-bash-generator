# 03 — search_capabilities

## Responsabilidade

`search_capabilities` recebe uma `NormalizedRequest` com status `READY` e procura capabilities ativas que possam resolver:

1. a requisição completa;
2. cada tarefa individualmente.

Não utiliza LLM.

## Entrada

```proto
message SearchCapabilitiesRequest {
  NormalizedRequest request = 1;
  SearchBudget budget = 2;
}
```

`SearchBudget` limita o crescimento do contexto:

```text
composite_limit
per_task_limit
global_candidate_limit
max_capability_details
```

## Duas fases

### 1. Candidate retrieval

PostgreSQL procura por:

- intent exato;
- Full Text Search;
- enabled;
- versão ativa;
- status ativo.

### 2. Deterministic pruning

Antes do LLM, a aplicação remove candidatos incompatíveis usando:

- `CapabilityType`;
- `CapabilityInterface.stdin_contract`;
- argumentos;
- `stdout_contract`;
- `DataKind`;
- campos obrigatórios;
- `StreamEncoding`;
- política/plataforma.

Full Text Search localiza candidatos. Ele não decide compatibilidade.

## Busca composta

Usa:

```text
intent
canonical_instruction
input_description
output_description
```

e verifica a interface estruturada da capability contra a entrada e saída globais.

## Busca por tarefa

Quando nenhuma solução composta adequada existe, buscar por cada `NormalizedTask`.

## Saída

```proto
message SearchCapabilitiesResponse {
  repeated CapabilityCandidate composite_candidates = 1;
  repeated TaskCandidates task_candidates = 2;
}
```

O objeto interno pode carregar a interface estruturada.

Na visão TextProto do LLM, após o pruning, retornar preferencialmente apenas:

```text
id
type
description
match_instruction
input_description
output_description
```

Assim o LLM não paga novamente por informações que a aplicação já validou.

## Deduplicação

O mesmo ID pode aparecer em múltiplas buscas.

Antes de montar a visão do gerador:

- deduplicar IDs globalmente;
- respeitar `global_candidate_limit`;
- preservar a associação do candidato com as tarefas em que ele é aplicável.

## Registro de uso

`search_capabilities` não registra uso.

O evento ocorre quando a versão completa é carregada por `get_capability`.

## Falha

Zero candidatos é um resultado válido.

O pipeline segue para o `bash-generator`, que poderá gerar somente as capabilities ausentes.
