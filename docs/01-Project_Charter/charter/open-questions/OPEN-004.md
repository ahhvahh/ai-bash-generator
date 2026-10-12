# OPEN-004 — Intercâmbio de dados entre capacidades

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Qual compromisso funcional de compatibilidade entre entradas, resultados e erros de capacidades é necessário para compor tarefas distintas?

## Contexto para refinamento

Uma operação pode produzir dados para outra, incluindo coleções, objetos e valores simples. Também foi considerada a necessidade de manter diagnósticos separados dos resultados funcionais e de preservar dependências quando tarefas independentes são processadas. O formato físico de intercâmbio foi tratado anteriormente como opção de implementação.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais categorias de dados e erros devem ser transmitidas de forma inequívoca?
- A composição de resultados de múltiplas atividades é necessária desde a primeira versão?
- Quais evidências permitem confirmar que não houve perda ou alteração indevida dos dados?

## Impacto

Pode impedir reutilização e composição confiáveis se contratos divergirem; o transporte específico pertence à etapa posterior.

## Bloqueadora

Não — o requisito funcional é tratável em Scope.

## Próxima ação

Confirmar critérios de compatibilidade, resultados e tratamento de falhas em alto nível.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [OBJ-002](../objectives/OBJ-002.md)

## Resultado funcional esperado do intercâmbio

**DOCUMENTED:** composição de tarefas é parte da finalidade do produto. Cada função precisa declarar de forma verificável a estrutura lógica de entrada e de saída, permitindo que os resultados de uma etapa satisfaçam as entradas de outra, inclusive estruturas, listas e agregações. A composição deve preservar tipos, dependências e identificação de falhas, conforme [OBJ-006](../objectives/OBJ-006.md). A busca de [OBJ-002](../objectives/OBJ-002.md) avalia contratos, não valores concretos nem amostras do SO. 

**PENDING —** como serializar coleções, multiplexar resultados e propagar erros entre funções; essas são especificações técnicas de Scope/Implementation, sem fixação neste Charter.
