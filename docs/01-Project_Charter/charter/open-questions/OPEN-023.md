# OPEN-023 — Governança de capacidades publicadas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quem autoriza uma nova capacidade a ficar disponível para reutilização e sob quais evidências e condições de reversão?

## Contexto e evidência histórica

ADR-0007 indica publicação inicial sem ativação automática; fluxo de publicação e catálogo descrevem candidates, ativação e bloqueio, mas pendências administrativas persistem.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta confiabilidade, responsabilização e permissões para o reaproveitamento automático.

## Bloqueadora

Sim — ativação de capacidade automática afeta a fronteira de segurança do produto.

## Próxima ação

Definir política de aprovação em alto nível e se a ativação pode ser automática; encaminhar operações de administração ao Scope.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [docs/adr/geracao/capabilities-geradas.md](../../../adr/geracao/capabilities-geradas.md)
- [docs/especificacao/fluxos/publicacao-capability.md](../../../especificacao/fluxos/publicacao-capability.md)
- [docs/especificacao/persistencia/catalogo-capabilities.md](../../../especificacao/persistencia/catalogo-capabilities.md)
- [docs/pendencias.md](../../../pendencias.md)
