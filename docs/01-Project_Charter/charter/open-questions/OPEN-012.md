# OPEN-012 — Isolamento e complexidade das capacidades geradas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais limites de complexidade e previsibilidade são necessários para que novas capacidades sejam seguras e avaliáveis na V1?

## Contexto para refinamento

Capacidades geradas podem introduzir efeitos inesperados antes da execução da operação principal ou interferir umas nas outras. Foi considerada uma limitação inicial a definições pequenas, com nomes exclusivos e sem execução indireta durante sua incorporação ao artefato. O Charter deve definir o risco aceitável e a necessidade de isolamento, sem impor sintaxe ou técnica de validação.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Que efeitos colaterais são inaceitáveis quando uma capacidade é incorporada?
- Há necessidade de limitar a complexidade da geração na primeira versão?
- Qual evidência mínima demonstrará isolamento e ausência de execução inesperada?

## Impacto

Afeta risco de efeitos inesperados, escopo inicial e critérios de validação.

## Bloqueadora

Sim — o alcance e as garantias de segurança da geração precisam ser confirmados.

## Próxima ação

Definir limites funcionais e garantias de comportamento; a sintaxe e os validadores ficam nas fases técnicas.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-020](OPEN-020.md)
