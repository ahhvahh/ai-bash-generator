# Project Charter — ai-bash-gen

![Tipo: PCH](assets/documentation-style/badges/badge-type-pch.svg) ![Status: refinement](assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](assets/documentation-style/badges/badge-version-v1.svg)

**Documento principal:** [PCH-001](charter/PCH-001.md)  

## Propósito

Registrar o problema, o propósito, os resultados, as exclusões e os limites que fundamentarão o escopo do ai-bash-gen, segundo o padrão [ProjectCharter/1.0](https://github.com/ahhvahh/doc-arquitetura/tree/main/ProjectCharter/1.0).

## Índice

- [Charter](charter/README.md)
- [PCH-001 — Geração e execução de scripts Bash com permissões controladas](charter/PCH-001.md)
- [OBJ-001 — Gerar scripts Bash a partir de linguagem natural](charter/objectives/OBJ-001.md)
- [OBJ-002 — Reutilizar capacidades existentes](charter/objectives/OBJ-002.md)
- [OBJ-003 — Decompor solicitações em tarefas verificáveis](charter/objectives/OBJ-003.md)
- [OBJ-004 — Revisar independentemente funções e corrigir divergências](charter/objectives/OBJ-004.md)
- [OBJ-005 — Executar artefatos aprovados e entregar resultados rastreáveis](charter/objectives/OBJ-005.md)
- [NOBJ-001 — Não executar além das permissões do serviço](charter/non-objectives/NOBJ-001.md)
- [CON-001 — Operação offline e APIs externas opcionais](charter/constraints/CON-001.md)
- [CON-002 — Recursos mínimos de execução](charter/constraints/CON-002.md)
- [ASM-001 — Premissa de desempenho na configuração de referência](charter/assumptions/ASM-001.md)
- [OPEN-001 — Critérios mensuráveis de sucesso](charter/open-questions/OPEN-001.md)

## Autonomia documental e controle

O Charter contém integralmente os requisitos e as questões que fundamentam suas decisões. Nenhuma decisão depende de documentos anteriores à pasta `docs/01-Project_Charter/`; informações históricas relevantes foram incorporadas como contexto de refinamento às questões internas, sem importar seus contratos técnicos.

- **Base de intenção:** [PCH-001](charter/PCH-001.md), seus objetivos, restrições, premissas e [questões em refinamento](charter/README.md).
- **Referência de método (somente leitura):** [ProjectCharter/1.0](https://github.com/ahhvahh/doc-arquitetura/tree/main/ProjectCharter/1.0).
- **Baseline normativa consultada:** `cff50e1115373060a3d1172c6b3621c1bde0ba6e`.
- A origem histórica não é uma fonte normativa vinculada ao Charter; qualquer escolha só se torna compromisso após refinamento e registro no documento canônico interno.

## Gate Charter → Scope

**BLOCKED.** A meta de geração (90% em 20 solicitações) está definida, mas os 20 casos e seus resultados esperados, além da meta específica de reutilização, seguem pendentes em [OPEN-001](charter/open-questions/OPEN-001.md). Os documentos necessários ainda estão em `refinement`.
