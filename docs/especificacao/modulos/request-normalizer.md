# Request Normalizer

![MOD](https://img.shields.io/badge/MOD-MOD--0001-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Transformar linguagem natural em uma `NormalizedRequest` estruturada, independente de implementação e suficiente para localizar ou gerar uma solução para cada tarefa.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [CTR-0001 — Protobuf do pipeline](../contratos/pipeline-protobuf.md)
- [PRM-0001 — Prompt do normalizador](../prompts/request-normalizer.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Responsabilidades

- decompor o objetivo em tasks semanticamente independentes;
- representar cada task por input lógico estruturado, instruction e output contract;
- preservar valores literais fornecidos pelo usuário;
- ligar dependências reais de dados por `result_ref`;
- registrar dependências exclusivamente de controle por `depends_on`;
- permitir zero, um ou vários consumidores para um output;
- identificar informação obrigatória ausente;
- não escolher capability, comando, aplicação, script, serviço ou forma de invocation;
- não criar tasks artificiais apenas para serializar trabalho que pode ser independente.

## Entradas

`UserRequest.text`.

O `request_id` é interno e não pertence ao conteúdo fornecido pelo cliente.

## Saídas

`NormalizedRequest` contendo intenção, instrução canônica, tasks, dependências, saída final, status e entradas ausentes.

### Modelo lógico de task

Cada task representa conceitualmente:

```text
NormalizedTask
├── input
│   ├── valores literais
│   └── result_ref para resultados anteriores
├── instruction
└── output_contract
```

O **input** descreve os campos disponíveis e seus tipos.

A **instruction** descreve objetivamente o processamento necessário, sem indicar como executá-lo.

O **output contract** descreve a estrutura esperada do resultado, incluindo objetos, listas e valores escalares.

### DAG e ordem

As relações `result_ref` e `depends_on` formam o DAG da requisição.

A ordem serializada de `tasks` deve ser estável e respeitar precedência, mas não significa execução obrigatoriamente sequencial. Tasks sem dependência entre si podem ser executadas em paralelo pelo artifact gerado.

`result_ref` continua sendo a fonte de verdade para dependência de dados.

### Fan-out e fan-in

Um output pode alimentar vários consumidores sem duplicação lógica.

Uma task pode receber resultados de múltiplos predecessores. Nesse caso cada campo de input aponta para o `result_ref` correspondente; a montagem do objeto final de entrada é responsabilidade determinística do pipeline, não do normalizador.

Quando vários resultados precisam formar um novo significado funcional, essa transformação deve ser uma task explícita.

## Interfaces e contratos

- [CTR-0001](../contratos/pipeline-protobuf.md)

## Restrições

O normalizador não gera Bash, não chama tools, não pesquisa capabilities e não escolhe detalhes da ABI de execução.

A forma física atual do Protobuf pode manter campos legados de descrição durante a transição, mas a semântica normativa da task é input estruturado + instruction + output contract.

## Critérios de aceite

- cada task possui objetivo único e contratos determináveis;
- IDs e nomes de resultado são únicos;
- `result_ref` aponta somente para resultados existentes;
- o DAG é acíclico;
- tasks independentes não recebem dependências artificiais;
- `final_output_ref` existe quando o status é READY;
- `MISSING_INFORMATION` interrompe o pipeline antes da busca;
- nenhuma implementação shell ou detalhe de transporte aparece na intenção da task.

## Implementação relacionada

A implementação atual ainda deve ser reconciliada com esta arquitetura-alvo antes de o documento avançar para `refined`.
