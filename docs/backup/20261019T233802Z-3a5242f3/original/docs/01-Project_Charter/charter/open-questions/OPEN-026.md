# OPEN-026 — Instalação, ambiente de operação e portabilidade

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais distribuições, condições de instalação, modos de operação e garantias de portabilidade integram o compromisso do produto?

## Contexto para refinamento

A intenção do produto inclui operação em ambiente Linux com uma identidade dedicada e condições mínimas de recurso. A configuração vigente do Charter exige quatro CPUs e 8 GB de RAM; a referência anterior de dois núcleos e 8 GB não integra os requisitos atuais. Foram também consideradas diferentes formas de instalação e a necessidade de declarar recursos externos para executar os artefatos.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- A disponibilidade em um ambiente Linux específico é obrigação do produto ou apenas alvo inicial?
- O artefato precisa funcionar fora do ambiente que o gerou, e com quais pré-condições?
- Quais garantias de instalação, atualização e disponibilidade justificam critérios verificáveis de aceitação?

## Impacto

Afeta suporte, recursos, experiência de instalação e expectativas de execução offline.

## Bloqueadora

Sim — requisitos de plataforma e configuração mínima são restrições essenciais.

## Próxima ação

Confirmar plataformas e limites de suporte, corrigir eventual inconsistência com CON-002 e deixar empacotamento detalhado à Implementation.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [CON-002](../constraints/CON-002.md)
- [ASM-001](../assumptions/ASM-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
