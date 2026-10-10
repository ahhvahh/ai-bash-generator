# NOBJ-001 — Não executar automaticamente scripts gerados

![Tipo: NOBJ](../../assets/documentation-style/badges/badge-type-nobj.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**ID:** NOBJ-001  
**Status:** `refinement`  
**Version:** `v1`  
**Evidência:** `DOCUMENTED` no [README do projeto](../../../../README.md).

## Exclusão

Não é propósito do projeto executar automaticamente o script Bash produzido como consequência da geração.

## Justificativa

A geração e a execução possuem riscos e responsabilidades distintos. A saída deve poder ser revisada antes da execução.

## Efeito sobre expectativas

A geração de um script não significa que suas ações foram executadas no ambiente do usuário. A decisão de executá-lo pertence a operação independente e autorizada.

## Condição de revisão

Qualquer execução automatizada futura exige novo escopo e avaliação explícita dos riscos e permissões.
