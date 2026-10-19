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

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-002](../objectives/OBJ-002-reutilizar-capacidades-existentes.md)
- [NOBJ-001](../non-objectives/NOBJ-001-nao-executar-alem-das-permissoes-concedidas-ao-usuario-do-servico.md)

## Reuso de funções e plano de montagem

**DOCUMENTED:** o produto precisa compor capacidades pequenas em ordem lógica, mesmo quando recuperadas de fontes ou implementações distintas, desde que satisfaçam contratos abstratos exatamente compatíveis e regras de elegibilidade. O resultado é um conjunto de funções com versões fixas, entrada, saída e dependências explícitas, que permite à aplicação montar um script Bash verificável conforme [OBJ-006](../objectives/OBJ-006-compor-funcoes-reutilizaveis-em-um-fluxo-bash-verificavel.md). A pesquisa no catálogo não executa a capacidade. 

**PENDING —** mecanismos de adaptação e orquestração concretos, tratamento técnico de dados intermediários, ordenação e paralelismo; não adotar tecnologia específica no Charter.
