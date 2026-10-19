# OPEN-002 — Orquestração da geração e composição de resultados

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A separação entre interpretação por IA, reutilização de capacidades e composição determinística atende ao resultado de produto pretendido?

## Contexto para refinamento

Foi considerada uma organização em que a interpretação do pedido identifica atividades, a busca recupera capacidades já conhecidas e apenas as operações ainda não disponíveis exigem nova geração. A composição do resultado final seria previsível e independente de nova interpretação. O benefício pretendido é reduzir trabalho repetido, variabilidade e erros.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

**Decisão funcional aprovada:** organizar o processamento em três responsabilidades de LLM: planejamento e decomposição do pedido; geração de funções Bash quando não houver reutilização exata; revisão independente de cada candidata e da composição frente à solicitação original. A revisão pode devolver reprovações corrigíveis à geração dentro de limites configuráveis, conforme [OBJ-003](../objectives/OBJ-003-decompor-solicitacoes-em-tarefas-verificaveis.md), [OBJ-004](../objectives/OBJ-004-revisar-independentemente-funcoes-e-corrigir-divergencias.md) e [OPEN-014](OPEN-014-orcamento-de-processamento-e-recuperacao.md).

A busca por capacidades compatíveis precede a geração conforme [OBJ-002](../objectives/OBJ-002-reutilizar-capacidades-existentes.md). Um parecer favorável da revisora não substitui a validação de segurança em [OPEN-020](OPEN-020-garantias-de-validacao-antes-de-gerar-e-executar.md).

**PENDING — representação técnica de tarefas, seleção de modelos e prompts operacionais**, para Scope/Implementation.

## Impacto

O resultado esperado deve distinguir geração, reaproveitamento e garantia de previsibilidade, sem impor a implementação nesta etapa.

## Bloqueadora

Não — a escolha do método pertence às etapas seguintes, desde que os objetivos de Charter sejam preservados.

## Próxima ação

Confirmar as garantias funcionais exigidas, verificar sua cobertura em OBJ-001/OBJ-002 e encaminhar a composição técnica a Scope/Implementation.

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-001](../objectives/OBJ-001-gerar-scripts-bash-a-partir-de-linguagem-natural.md)
- [OBJ-002](../objectives/OBJ-002-reutilizar-capacidades-existentes.md)

## Exemplos ilustrativos de prompts — não normativos

Estes textos demonstram intenção e responsabilidades. Não são prompts executáveis definitivos.

**LLM planejadora:**

> Interprete a solicitação original e decomponha-a em tarefas quando necessário. Para cada tarefa identifique finalidade, entradas, saídas, dependências, restrições e critérios de aceite. Preserve a intenção original; sinalize ambiguidades sem inventar parâmetros.

**LLM geradora:**

> Receba uma tarefa delimitada e seus critérios. Produza uma função Bash que atenda somente à finalidade solicitada, respeitando entradas, saídas e restrições. Não execute o código nem eleve privilégios. Se receber uma reprovação corrigível, gere uma nova candidata tratando o feedback.

**LLM revisora:**

> Compare a solicitação original, a tarefa, a função candidata e seus critérios de aceite. Identifique divergências de finalidade, entradas, saídas, efeitos colaterais e restrições. Emita parecer fundamentado: aprovado, reprovado corrigível, reprovado não corrigível ou inconclusivo. Seu parecer não autoriza execução.

A sintaxe, o contexto enviado e os critérios de qualidade dos prompts serão detalhados posteriormente.

## Síntese aprovada — composição funcional por tarefas

**DOCUMENTED:** a entrada pode estar em qualquer idioma. A LLM planejadora de [OBJ-003](../objectives/OBJ-003-decompor-solicitacoes-em-tarefas-verificaveis.md) normaliza o pedido, representa tarefas pequenas e comunica seus contratos abstratos de entrada e saída e a proposta de processamento. A busca de [OBJ-002](../objectives/OBJ-002-reutilizar-capacidades-existentes.md) considera somente estrutura lógica e propósito, **sem dados reais e sem executar operações**; em ausência de correspondência exata, [OBJ-001](../objectives/OBJ-001-gerar-scripts-bash-a-partir-de-linguagem-natural.md) gera a função candidata, que passa pela revisão independente de [OBJ-004](../objectives/OBJ-004-revisar-independentemente-funcoes-e-corrigir-divergencias.md).

A saída da orquestração é um conjunto de funções identificadas e versionadas, com dependências e relações de entrada/saída suficientes para a aplicação montar um Bash, conforme [OBJ-006](../objectives/OBJ-006-compor-funcoes-reutilizaveis-em-um-fluxo-bash-verificavel.md). O conjunto final validado segue à execução automática autorizada de [OBJ-005](../objectives/OBJ-005-executar-artefatos-aprovados-e-entregar-resultados-rastreaveis.md). A sequência funcional está ilustrada em [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md); detalhes de algoritmos, interfaces e serialização ficam para Scope/Implementation.
