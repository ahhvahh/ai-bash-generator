# Project Charter — ai-bash-gen

![Tipo: PCH](assets/documentation-style/badges/badge-type-pch.svg) ![Status: refinement](assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](assets/documentation-style/badges/badge-version-v1.svg)

**Documento principal:** [PCH-001](charter/PCH-001.md)  
**Status:** `refinement` · **Version:** `v1`

## Propósito

Registrar o problema, o propósito, os resultados, as exclusões e os limites que fundamentarão o escopo do ai-bash-gen, segundo o padrão [ProjectCharter/1.0](https://github.com/ahhvahh/doc-arquitetura/tree/main/ProjectCharter/1.0).

## Índice

- [Charter](charter/README.md)
- [PCH-001 — Geração local e segura de scripts Bash](charter/PCH-001.md)
- [OBJ-001 — Gerar scripts Bash a partir de linguagem natural](charter/objectives/OBJ-001.md)
- [OBJ-002 — Reutilizar capacidades existentes](charter/objectives/OBJ-002.md)
- [NOBJ-001 — Não executar scripts automaticamente](charter/non-objectives/NOBJ-001.md)
- [CON-001 — Operação offline e APIs externas opcionais](charter/constraints/CON-001.md)
- [CON-002 — Recursos mínimos de execução](charter/constraints/CON-002.md)
- [ASM-001 — Premissa de desempenho na configuração de referência](charter/assumptions/ASM-001.md)
- [OPEN-001 — Critérios mensuráveis de sucesso](charter/open-questions/OPEN-001.md)

## Fontes e controle

- [README do produto](../../README.md): intenção declarada, segurança e requisitos iniciais.
- [Documentação arquitetural existente](../README.md): decisões e pendências usadas como evidência contextual, sem substituir o Charter.
- Baseline normativa: `doc-arquitetura/main`, commit `22c4d07ab9478af6075733ba99a1c447eaf60842`.
- Nenhuma decisão técnica adicional é estabelecida por este Charter.

## Gate Charter → Scope

**BLOCKED.** A meta de geração (90% em 20 solicitações) está definida, mas os 20 casos e seus resultados esperados, além da meta específica de reutilização, seguem pendentes em [OPEN-001](charter/open-questions/OPEN-001.md). Os documentos necessários ainda estão em `refinement`.
