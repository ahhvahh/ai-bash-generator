# OPEN-011 — Composição de capacidades heterogêneas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

O produto deve reutilizar capacidades existentes mesmo quando suas implementações internas sejam diferentes, sem alterar o resultado esperado?

## Contexto para refinamento

Uma tarefa pode ser atendida por uma função interna ou por um recurso já disponível no ambiente de execução. Foi considerada a apresentação de capacidades diferentes por uma interface funcional comum, de modo que o solicitante não precise conhecer sua implementação. A tecnologia de adaptação pertence às próximas etapas.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- O sistema deve reutilizar recursos heterogêneos desde a primeira versão?
- Que garantias de equivalência de entrada, saída e erro são exigidas?
- Quais dependências precisam estar disponíveis antes de autorizar a execução?

## Impacto

Amplia potencial de reaproveitamento e limita dependência do produto de formas internas de execução.

## Bloqueadora

Não — o mecanismo de adaptação é uma decisão técnica posterior.

## Próxima ação

Decidir a abrangência da interoperabilidade esperada e vincular o requisito a OBJ-002.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-002](../objectives/OBJ-002.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
