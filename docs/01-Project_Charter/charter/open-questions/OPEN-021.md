# OPEN-021 — Cancelamento, tempo limite e falhas operacionais

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Que garantias o serviço deve oferecer para encerrar solicitações e atividades automáticas quando ocorrer cancelamento, indisponibilidade ou timeout?

## Contexto e evidência histórica

FLW de cancelamento e CTR API registram regras técnicas parcialmente abertas, inclusive propagação de cancelamento e deadlines.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta segurança operacional, limite de consumo de recursos e previsibilidade de falhas.

## Bloqueadora

Sim — comportamento seguro de interrupção de execução precisa ser delimitado no Charter.

## Próxima ação

Estabelecer compromissos de resultado do cancelamento e de encerramento seguro; detalhar propagação na etapa Scope.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/especificacao/fluxos/cancelamento-timeout.md](../../../especificacao/fluxos/cancelamento-timeout.md)
- [docs/especificacao/contratos/api-daemon.md](../../../especificacao/contratos/api-daemon.md)
- [docs/adr/api/protocolo-daemon.md](../../../adr/api/protocolo-daemon.md)
- [docs/pendencias.md](../../../pendencias.md)
