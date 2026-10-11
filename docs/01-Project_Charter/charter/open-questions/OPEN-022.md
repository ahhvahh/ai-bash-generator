# OPEN-022 — Geração versus execução automática do artefato

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Em que momento o artefato gerado é executado automaticamente, e quais condições devem obrigatoriamente preceder essa execução?

## Contexto para refinamento

A intenção vigente do Charter inclui executar automaticamente scripts gerados no próprio sistema operacional por uma conta de serviço dedicada, limitada às permissões configuradas pelo administrador. Em interpretações anteriores, geração e execução eram atividades separadas, sem acionamento automático. O projeto precisa confirmar a sequência funcional, o instante de execução e as validações obrigatórias antes de efetivar o comportamento atual.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Qual evento autoriza ou dispara a execução depois da geração?
- Quais condições de validação, disponibilidade e segurança são pré-requisitos obrigatórios?
- Como o solicitante recebe o resultado real da execução e como são tratadas falhas e cancelamentos?

## Impacto

Inconsistência sobre o acionamento automático entre documentos legados e Charter vigente; impacto em segurança, fluxo e teste.

## Bloqueadora

Sim — contradição funcional essencial e gate bloqueado.

## Próxima ação

Confirmar evento de execução, controles prévios, identidade executora e resposta em caso de erro; atualizar a decisão canônica de Charter por aprovação.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-013](OPEN-013.md)
- [OPEN-020](OPEN-020.md)
