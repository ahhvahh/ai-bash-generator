# OPEN-010 — Separação entre intenção e mecanismos técnicos

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A tarefa deve ser descrita por propósito, dados necessários e resultado esperado, sem impor antecipadamente uma ferramenta de execução?

## Contexto para refinamento

A descrição de uma tarefa deve expressar o que precisa ser feito e quais dados são esperados sem obrigar o solicitante a escolher comandos, formatos ou mecanismos internos. Foi considerada a separação entre significado do pedido e representação necessária para executá-lo. O compromisso do Charter deve ser com a independência funcional, não com um formato específico.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- O solicitante precisa conhecer ferramentas ou formatos para obter um resultado correto?
- Quais informações sobre entrada e saída são essenciais para comparar capacidades?
- Que perdas de significado ou ambiguidades devem resultar em pedido de esclarecimento?

## Impacto

Preserva neutralidade de solução e favorece reuso, mas contratos físicos são da etapa seguinte.

## Bloqueadora

Não — a semântica funcional pode ser refinada em Scope.

## Próxima ação

Validar que a intenção do solicitante seja preservada e retirar especificações de transporte do Charter.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [OBJ-002](../objectives/OBJ-002.md)
