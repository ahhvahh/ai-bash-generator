# Bash Output e Assembler

![MOD](https://img.shields.io/badge/MOD-MOD--0005-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Montar deterministicamente o script Bash final a partir de tasks e functions validadas e materializar o `BashArtifact`.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0003 — ABI JSON](../../adr/execucao/abi-stdout-stdin.md)
- [ADR-0006 — Publicação e materialização](../../adr/pipeline/publicacao-materializacao.md)
- [ADR-0010 — Binding por função](../../adr/execucao/binding-invocacao.md)
- [ADR-0016 — Limite de paralelismo do DAG](../../adr/execucao/limite-paralelismo-dag.md)
- [CTR-0005 — ABI JSON de functions](../contratos/function-json.md)

## Responsabilidades

- incorporar ao artifact as functions resolvidas;
- preservar nomes e referências definidos pelo conjunto validado;
- gerar uma função central que execute o DAG;
- liberar tasks quando suas dependências estiverem satisfeitas;
- representar tasks independentes de forma que possam executar em paralelo;
- montar deterministicamente objetos JSON de input a partir de valores literais e `result_ref`;
- realizar fan-in por Input Binder, sem criar capability artificial;
- conectar a saída final solicitada;
- calcular SHA-256 do artifact;
- gravar de forma atômica;
- não executar o artifact durante a geração.

## Entradas

Resultado validado contendo:

- DAG de tasks;
- contratos lógicos;
- versões de capabilities resolvidas;
- functions Bash correspondentes;
- referência da saída final;
- nome solicitado para o artifact.

## Saídas

`BashArtifact` contendo nome, conteúdo, checksum e referência de saída final.

## Composição

O assembler não converte campos da task diretamente em flags ou argumentos de aplicações.

Para cada nó do DAG ele conhece apenas:

- objeto JSON de entrada;
- function Bash a chamar;
- objeto JSON de saída esperado;
- dependências de dados e controle.

Implementações externas são encapsuladas pelos wrappers das capabilities.

## Paralelismo

Tasks sem dependência entre si são nós independentes e podem ser iniciadas em paralelo.

Na V1, uma execução do artifact pode manter no máximo **4 tasks simultaneamente em execução**. Quando as quatro vagas estiverem ocupadas, novas tasks prontas aguardam a liberação de uma vaga.

Uma task dependente só pode ser iniciada quando todos os predecessores necessários estiverem concluídos com sucesso.

Quando houver múltiplos predecessores, o Input Binder monta o único JSON de entrada esperado pela próxima function.

O mecanismo concreto de buffering ou materialização de resultados paralelos e a regra para escolher entre múltiplas tasks prontas ainda precisam ser refinados; o assembler não deve escolher esses detalhes por suposição.

## Restrições

- aceita somente conjunto validado;
- inclui `set -euo pipefail` enquanto compatível com os contratos de erro definidos;
- permissão inicial documentada: `0640`;
- valores são dados JSON, nunca fragmentos shell;
- publicação no catálogo não é responsabilidade deste módulo;
- nenhuma LLM participa da composição.

## BLOCKED

A especificação não pode atingir `refined` até serem definidos:

- regra de seleção entre múltiplas tasks prontas quando houver mais candidatas do que vagas;
- estratégia de buffering/materialização de outputs paralelos;
- semântica completa de falhas em branches paralelos;
- manifesto final de dependências do artifact.

## Critérios de aceite

- conteúdo deriva somente do DAG e das functions validadas;
- tasks independentes não são serializadas artificialmente;
- nenhuma execução mantém mais de quatro tasks simultâneas;
- fan-in não cria task funcional sem necessidade;
- o assembler não contém lógica específica para APPLICATION, SCRIPT ou SERVICE;
- gravação usa estratégia atômica;
- o artifact não é executado automaticamente.

## Implementação relacionada

Arquitetura-alvo ainda não verificada na implementação atual.
