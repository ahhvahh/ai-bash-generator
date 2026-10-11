# OPEN-022 — Geração versus execução automática do artefato

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Em que momento o artefato gerado é executado automaticamente, e quais condições devem obrigatoriamente preceder essa execução?

## Contexto e evidência histórica

PCH-001 e NOBJ-001 atuais incluem execução automática pela conta de serviço. O README principal e o ADR-0015 negam execução automática, enquanto ADR-0001 e ADR-0012 descrevem a separação entre geração e execução. Esta Open Question deve conciliar o acionamento automático com as fronteiras de cada etapa, sem apagar o histórico.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Inconsistência sobre o acionamento automático entre documentos legados e Charter vigente; impacto em segurança, fluxo e teste.

## Bloqueadora

Sim — contradição funcional essencial e gate bloqueado.

## Próxima ação

Confirmar evento de execução, controles prévios, identidade executora e resposta em caso de erro; atualizar a decisão canônica de Charter por aprovação.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [README.md](../../../../README.md)
- [docs/adr/pipeline/pipeline-hibrido.md](../../../adr/pipeline/pipeline-hibrido.md)
- [docs/adr/seguranca/efeitos-capabilities.md](../../../adr/seguranca/efeitos-capabilities.md)
- [docs/adr/api/protocolo-daemon.md](../../../adr/api/protocolo-daemon.md)
- [docs/especificacao/fluxos/execucao-artifact.md](../../../especificacao/fluxos/execucao-artifact.md)
