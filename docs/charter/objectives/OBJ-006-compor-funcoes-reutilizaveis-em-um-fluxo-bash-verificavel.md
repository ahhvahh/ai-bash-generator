# OBJ-006 — Compor funções reutilizáveis em um fluxo Bash verificável

![Tipo: OBJ](../../assets/documentation-style/badges/badge-type-obj.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**Evidência:** `DOCUMENTED` — decisão funcional aprovada pelo responsável pelo projeto; implementação e testes não verificados.

## Motivação

Permitir resolver pedidos complexos mediante várias tarefas pequenas sem gerar novamente funções existentes nem perder compatibilidade ao montar um script Bash.

## Resultado esperado

Após resolver todas as tarefas por reutilização exata ou geração aprovada, o produto entrega à aplicação responsável pela montagem um **conjunto estruturado de funções Bash**, com identidade e versão, entrada e saída lógicas, dependências e sequência funcional necessária. A aplicação pode montar um Bash que encadeia funções e preserva os dados e resultados de cada etapa. A composição e a execução são responsabilidades distintas; a consulta ao catálogo não executa código.

## Critérios verificáveis

- Cada tarefa necessária à intenção original está associada à função escolhida ou a uma falha explícita que impede concluir o conjunto.
- As funções reutilizadas mantêm versões imutavelmente selecionadas durante toda a requisição, conforme [OBJ-002](OBJ-002-reutilizar-capacidades-existentes.md).
- Entradas e saídas de tarefas dependentes são logicamente compatíveis; dependências e ordem necessária são preservadas.
- O conjunto devolvido contém informações suficientes para a aplicação montar o Bash, sem exigir que uma LLM concatene comandos livremente.
- A composição final pode ser avaliada frente à solicitação original por [OBJ-004](OBJ-004-revisar-independentemente-funcoes-e-corrigir-divergencias.md), antes das validações e da execução de [OBJ-005](OBJ-005-executar-artefatos-aprovados-e-entregar-resultados-rastreaveis.md).
- Uma falha de composição não é tratada como sucesso ou como autorização de execução.

## Limites

Não define DAG físico, interfaces, serialização, algoritmo de montagem, paralelismo, mecanismo de execução ou tecnologia do serviço. Essas escolhas pertencem a Scope/Implementation. A aprovação semântica não substitui os controles de segurança em [OPEN-020](../open-questions/OPEN-020-garantias-de-validacao-antes-de-gerar-e-executar.md). **PENDING —** casos de teste e metas para composição em [OPEN-001](../open-questions/OPEN-001-criterios-mensuraveis-de-sucesso.md).

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-001](OBJ-001-gerar-scripts-bash-a-partir-de-linguagem-natural.md)
- [OBJ-002](OBJ-002-reutilizar-capacidades-existentes.md)
- [OBJ-003](OBJ-003-decompor-solicitacoes-em-tarefas-verificaveis.md)
- [OBJ-004](OBJ-004-revisar-independentemente-funcoes-e-corrigir-divergencias.md)
- [OBJ-005](OBJ-005-executar-artefatos-aprovados-e-entregar-resultados-rastreaveis.md)
- [OPEN-002](../open-questions/OPEN-002-orquestracao-da-geracao-e-composicao-de-resultados.md)
- [OPEN-004](../open-questions/OPEN-004-intercambio-de-dados-entre-capacidades.md)
- [OPEN-011](../open-questions/OPEN-011-composicao-de-capacidades-heterogeneas.md)
- [OPEN-020](../open-questions/OPEN-020-garantias-de-validacao-antes-de-gerar-e-executar.md)
