# OPEN-017 — Concorrência e previsibilidade de tarefas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais garantias de paralelismo, ordenação, limites de recursos e falhas devem ser observáveis nas automações?

## Contexto para refinamento

Pedidos podem ser compostos por tarefas com dependências reais e outras sem dependência entre si. Foi considerado permitir trabalho concorrente com limite inicial de quatro tarefas por artefato, para reduzir espera sem consumo descontrolado. Permanecem incertos o tratamento de falhas de uma ramificação, a seleção de tarefas prontas e a preservação dos resultados intermediários.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- O produto precisa executar tarefas independentes em paralelo desde a primeira versão?
- Que limites observáveis de consumo e duração devem prevalecer em cenários concorrentes?
- Como evitar a entrega de resultado incompleto quando uma atividade falha ou é cancelada?

## Impacto

Afeta desempenho, consumo de recursos e integridade de resultados quando existem tarefas independentes.

## Bloqueadora

Não — algoritmo e limite de concorrência operacional devem ser tratados após as metas de produto.

## Próxima ação

Validar a necessidade de execução simultânea e seus critérios de sucesso; manter escalonamento técnico pendente.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [ASM-001](../assumptions/ASM-001.md)
- [OPEN-021](OPEN-021.md)
