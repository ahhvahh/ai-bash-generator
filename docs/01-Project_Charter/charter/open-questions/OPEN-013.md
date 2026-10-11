# OPEN-013 — Identidade e privilégios de execução

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A execução automática deve ocorrer sempre pela identidade dedicada do serviço e exclusivamente com as permissões que o administrador lhe atribuir?

## Contexto e evidência histórica

ADR-0012 refere-se à identidade do usuário/processo executor do artifact. PCH-001 e NOBJ-001 vigentes descrevem execução automática por conta de serviço dedicada. Há divergência contextual entre os documentos, que não deve ser resolvida por inferência.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Define a fronteira de segurança, responsabilidade operacional e controles exigidos pelo produto.

## Bloqueadora

Sim — divergência material entre referências históricas e Charter vigente.

## Próxima ação

Confirmar o ator executor e harmonizar PCH-001/NOBJ-001 com os requisitos futuros, sem modificar o ADR histórico.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/seguranca/efeitos-capabilities.md](../../../adr/seguranca/efeitos-capabilities.md)
- [docs/especificacao/fluxos/execucao-artifact.md](../../../especificacao/fluxos/execucao-artifact.md)
- [README.md](../../../../README.md)
