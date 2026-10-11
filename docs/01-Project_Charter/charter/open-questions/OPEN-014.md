# OPEN-014 — Orçamento de processamento e recuperação

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Que limites de custo, tempo e tentativas de geração são aceitáveis para o solicitante sem comprometer completude ou segurança?

## Contexto para refinamento

O processamento de uma tarefa não resolvida pode exigir várias interações com inferência, consulta a ferramentas e correção de resultados inválidos. Foi considerada a redução de contexto ao mínimo necessário para essa tarefa, evitando reprocessar capacidades já conhecidas. Ainda faltam critérios de aceitação para consumo de recursos, tempo de resposta e comportamento ao esgotar limites.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais limites de duração e consumo devem ser estabelecidos como compromisso de produto?
- Quantas tentativas de correção fazem sentido antes de devolver falha?
- Como informar interrupção por limite sem mascarar resultados incompletos?

## Impacto

Afeta expectativas de latência, uso local de recursos e uso opcional de provedores externos.

## Bloqueadora

Não — números e algoritmo de orçamento pertencem às etapas seguintes, após metas de produto.

## Próxima ação

Definir exigências mensuráveis de custo e duração quando relevantes; elaborar orçamento técnico depois.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [ASM-001](../assumptions/ASM-001.md)
- [CON-002](../constraints/CON-002.md)
- [OPEN-001](OPEN-001.md)
