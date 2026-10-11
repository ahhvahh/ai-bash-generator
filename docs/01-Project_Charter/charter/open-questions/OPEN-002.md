# OPEN-002 — Orquestração da geração e composição de resultados

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A separação entre interpretação por IA, reutilização de capacidades e composição determinística atende ao resultado de produto pretendido?

## Contexto para refinamento

Foi considerada uma organização em que a interpretação do pedido identifica atividades, a busca recupera capacidades já conhecidas e apenas as operações ainda não disponíveis exigem nova geração. A composição do resultado final seria previsível e independente de nova interpretação. O benefício pretendido é reduzir trabalho repetido, variabilidade e erros.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- A previsibilidade do resultado e o reaproveitamento são garantias obrigatórias do produto?
- Quando a geração de nova capacidade deve ser evitada em favor de uma existente?
- Que critérios de sucesso comprovam a separação das responsabilidades sem impor um desenho técnico?

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
