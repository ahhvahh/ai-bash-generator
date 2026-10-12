# OPEN-002 — Orquestração da geração e composição de resultados

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A separação entre interpretação por IA, reutilização de capacidades e composição determinística atende ao resultado de produto pretendido?

## Contexto para refinamento

Foi considerada uma organização em que a interpretação do pedido identifica atividades, a busca recupera capacidades já conhecidas e apenas as operações ainda não disponíveis exigem nova geração. A composição do resultado final seria previsível e independente de nova interpretação. O benefício pretendido é reduzir trabalho repetido, variabilidade e erros.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

**Decisão funcional aprovada:** organizar o processamento em três responsabilidades de LLM: planejamento e decomposição do pedido; geração de funções Bash quando não houver reutilização exata; revisão independente de cada candidata e da composição frente à solicitação original. A revisão pode devolver reprovações corrigíveis à geração dentro de limites configuráveis, conforme [OBJ-003](../objectives/OBJ-003.md), [OBJ-004](../objectives/OBJ-004.md) e [OPEN-014](OPEN-014.md).

A busca por capacidades compatíveis precede a geração conforme [OBJ-002](../objectives/OBJ-002.md). Um parecer favorável da revisora não substitui a validação de segurança em [OPEN-020](OPEN-020.md).

**PENDING — representação técnica de tarefas, seleção de modelos e prompts operacionais**, para Scope/Implementation.

## Impacto

O resultado esperado deve distinguir geração, reaproveitamento e garantia de previsibilidade, sem impor a implementação nesta etapa.

## Bloqueadora

Não — a escolha do método pertence às etapas seguintes, desde que os objetivos de Charter sejam preservados.

## Próxima ação

Confirmar as garantias funcionais exigidas, verificar sua cobertura em OBJ-001/OBJ-002 e encaminhar a composição técnica a Scope/Implementation.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [OBJ-002](../objectives/OBJ-002.md)

## Exemplos ilustrativos de prompts — não normativos

Estes textos demonstram intenção e responsabilidades. Não são prompts executáveis definitivos.

**LLM planejadora:**

> Interprete a solicitação original e decomponha-a em tarefas quando necessário. Para cada tarefa identifique finalidade, entradas, saídas, dependências, restrições e critérios de aceite. Preserve a intenção original; sinalize ambiguidades sem inventar parâmetros.

**LLM geradora:**

> Receba uma tarefa delimitada e seus critérios. Produza uma função Bash que atenda somente à finalidade solicitada, respeitando entradas, saídas e restrições. Não execute o código nem eleve privilégios. Se receber uma reprovação corrigível, gere uma nova candidata tratando o feedback.

**LLM revisora:**

> Compare a solicitação original, a tarefa, a função candidata e seus critérios de aceite. Identifique divergências de finalidade, entradas, saídas, efeitos colaterais e restrições. Emita parecer fundamentado: aprovado, reprovado corrigível, reprovado não corrigível ou inconclusivo. Seu parecer não autoriza execução.

A sintaxe, o contexto enviado e os critérios de qualidade dos prompts serão detalhados posteriormente.
