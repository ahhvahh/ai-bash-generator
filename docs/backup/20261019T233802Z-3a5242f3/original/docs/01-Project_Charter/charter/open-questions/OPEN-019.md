# OPEN-019 — Tratamento de solicitações incompletas ou fora do escopo

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

O que o solicitante deve receber quando faltarem informações indispensáveis, quando houver ambiguidade ou quando a solicitação não for suportada?

## Contexto para refinamento

Pedidos em linguagem natural podem omitir parâmetros obrigatórios, solicitar comportamento incompatível ou conter ambiguidades que alterem o efeito da operação. Foi considerada a interrupção da geração nesses casos, com solicitação de esclarecimentos em vez de inventar valores. O resultado esperado deve diferenciar uma solicitação incompleta de uma solicitação não suportada.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais lacunas devem impedir automaticamente a geração ou execução?
- O que deve ser devolvido ao solicitante para possibilitar correção do pedido?
- Quando recusar uma solicitação é um resultado correto e mensurável, e não uma falha do produto?

## Impacto

Afeta confiança do usuário, integridade da execução automática e observabilidade do motivo de não atendimento.

## Bloqueadora

Sim — tratamento de solicitações que não podem ser executadas é uma garantia funcional importante.

## Próxima ação

Definir comportamento esperado e condições de não atendimento; tratar modelos de erro em Scope.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [OPEN-001](OPEN-001.md)
- [OPEN-020](OPEN-020.md)
