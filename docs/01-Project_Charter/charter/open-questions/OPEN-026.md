# OPEN-026 — Instalação, ambiente de operação e portabilidade

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais distribuições, condições de instalação, modos de operação e garantias de portabilidade integram o compromisso do produto?

## Contexto e evidência histórica

README principal trata de distribuição Debian, serviço e instalação; FLW de execução distingue dependência de host e artefato autocontido. CON-002 fixa mínimo de quatro CPUs e 8 GB de RAM, divergindo do README legado.

A decisão ou proposta no documento de origem está classificada como **DOCUMENTED**; a revalidação aqui é **PROPOSED**, sem comprovação adicional de implementação. A criação desta questão não revoga automaticamente uma decisão vigente.

## Impacto

Afeta suporte, recursos, experiência de instalação e expectativas de execução offline.

## Bloqueadora

Sim — requisitos de plataforma e configuração mínima são restrições essenciais.

## Próxima ação

Confirmar plataformas e limites de suporte, corrigir eventual inconsistência com CON-002 e deixar empacotamento detalhado à Implementation.

## Relações de Charter

[PCH-001 — Propósito do projeto](../PCH-001.md). Quando aplicável, revisar os documentos canônicos já existentes antes de criar objetivos, restrições ou premissas adicionais.

## Fontes para refinamento

- [README.md](../../../../README.md)
- [src/go/README.md](../../../../src/go/README.md)
- [docs/especificacao/fluxos/execucao-artifact.md](../../../especificacao/fluxos/execucao-artifact.md)
- [docs/especificacao/persistencia/catalogo-capabilities.md](../../../especificacao/persistencia/catalogo-capabilities.md)
- [docs/pendencias.md](../../../pendencias.md)
