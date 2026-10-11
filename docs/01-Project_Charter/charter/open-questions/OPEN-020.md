# OPEN-020 — Garantias de validação antes de gerar e executar

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais validações e evidências são obrigatórias antes de permitir a execução automática de um script gerado?

## Contexto para refinamento

A criação de scripts e sua execução automática apresentam riscos distintos. Antes da execução foi considerada a necessidade de validar sintaxe, coerência com a finalidade, conformidade de entradas e saídas, dependências e permissões efetivas. A análise estática oferece evidências limitadas sobre o comportamento real, portanto o Charter precisa determinar quais garantias são exigidas para considerar uma solicitação apta.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais verificações são indispensáveis antes de executar um script gerado?
- Que falhas obrigam bloqueio, pedido de correção ou rejeição da solicitação?
- Como medir segurança e correção sem executar código potencialmente perigoso durante o teste de geração?

## Impacto

Sem critérios de aprovação e tratamento de falha, um resultado sintaticamente válido pode produzir efeitos diferentes dos pretendidos.

## Bloqueadora

Sim — segurança e critérios de aceite para execução automática dependem desta definição.

## Próxima ação

Separar avaliação estática de garantia de execução e definir em Charter condições de aceite e falha; deixar ferramentas/rotinas de validação para Scope/Implementation.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-001](OPEN-001.md)
- [OPEN-022](OPEN-022.md)
