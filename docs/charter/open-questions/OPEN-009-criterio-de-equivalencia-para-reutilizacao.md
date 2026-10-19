# OPEN-009 — Critério de equivalência para reutilização

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A igualdade exata de propósito, entrada e saída e a manutenção da mesma versão durante a solicitação continuam sendo os requisitos da V1?

## Contexto para refinamento

O objetivo vigente de reutilização exige que propósito, entrada lógica e saída lógica sejam compatíveis, evitando que proximidade textual seja confundida com equivalência. Foi considerada a regra inicial de igualdade exata e a manutenção de uma versão estável durante a solicitação. É necessário reconsiderar se essa exigência atende os casos reais sem impedir reutilizações legítimas.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Igualdade exata continua sendo o critério adequado para todos os casos iniciais?
- Como demonstrar que uma capacidade equivalente foi reutilizada e uma incompatível foi recusada?
- Quais informações e resultados de testes são suficientes para aprovar esse compromisso?

## Impacto

Mudar o critério afeta o principal resultado de OBJ-002 e o conjunto de testes de reutilização.

## Bloqueadora

Sim — qualquer alteração exigiria revisão formal de OBJ-002.

## Próxima ação

Confirmar ou revisar explicitamente OBJ-002 e tratar em OPEN-001 apenas as métricas que ainda faltam.

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-002](../objectives/OBJ-002-reutilizar-capacidades-existentes.md)
- [OPEN-001](OPEN-001-criterios-mensuraveis-de-sucesso.md)
