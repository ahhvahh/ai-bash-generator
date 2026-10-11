# OPEN-016 — Acesso local e contrato externo do serviço

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais operações externas e garantias de erro, cancelamento e controle local o produto precisa oferecer?

## Contexto e evidência histórica

ADR-0015 está em refinamento e descreve protocolo externo local ainda incompleto. DSG-0003 e CTR-0004 estão associados à lacuna.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta capacidade de uso por clientes locais e previsibilidade do atendimento.

## Bloqueadora

Não — formato de mensagens, framing e transporte são responsabilidades posteriores.

## Próxima ação

Confirmar operações externas mínimas e limites de acesso; detalhar contratos em Scope.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/api/protocolo-daemon.md](../../../adr/api/protocolo-daemon.md)
- [docs/desenho/runtime-daemon.md](../../../desenho/runtime-daemon.md)
- [docs/especificacao/contratos/api-daemon.md](../../../especificacao/contratos/api-daemon.md)
