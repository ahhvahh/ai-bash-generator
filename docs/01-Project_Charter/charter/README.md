# Charter — ai-bash-gen

![Tipo: PCH](../assets/documentation-style/badges/badge-type-pch.svg) ![Status: refinement](../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../assets/documentation-style/badges/badge-version-v1.svg)

## Regra de organização

O documento [PCH-001](PCH-001.md) contém o propósito, problema, stakeholders e limites do projeto. Os documentos especializados evoluem de modo independente, sem antecipar Scope ou Implementation. Links normativos desta etapa apontam somente para outros documentos do próprio Charter; referências externas são limitadas ao padrão metodológico, quando necessárias.

## Índice de documentos canônicos

- [PCH-001 — Propósito e limites](PCH-001.md)
- [OBJ-001 — Geração de scripts](objectives/OBJ-001.md)
- [OBJ-002 — Reutilização de capacidades](objectives/OBJ-002.md)
- [NOBJ-001 — Não executar além das permissões do serviço](non-objectives/NOBJ-001.md)
- [CON-001 — Offline e processamento externo opcional](constraints/CON-001.md)
- [CON-002 — Recursos mínimos](constraints/CON-002.md)
- [ASM-001 — Desempenho na configuração mínima](assumptions/ASM-001.md)
- [OPEN-001 — Critérios de sucesso](open-questions/OPEN-001.md)

## Questões para refinamento do Charter

As questões abaixo contêm, em texto próprio, os assuntos e alternativas que precisam ser reconsiderados. O Charter não depende de documentos anteriores à sua estrutura. Cada decisão aprovada deve ser consolidada no documento canônico desta etapa, sem importar contratos de Scope ou decisões técnicas de Implementation.

- [OPEN-002 — Orquestração da geração e composição de resultados](open-questions/OPEN-002.md)
- [OPEN-003 — Contratos estruturados na interação com inferência](open-questions/OPEN-003.md)
- [OPEN-004 — Intercâmbio de dados entre capacidades](open-questions/OPEN-004.md)
- [OPEN-005 — Histórico e reprodutibilidade das capacidades](open-questions/OPEN-005.md)
- [OPEN-006 — Controle do acesso a ferramentas e integrações](open-questions/OPEN-006.md)
- [OPEN-007 — Publicação e entrega de resultados](open-questions/OPEN-007.md)
- [OPEN-008 — Limites da geração de novas capacidades](open-questions/OPEN-008.md)
- [OPEN-009 — Critério de equivalência para reutilização](open-questions/OPEN-009.md)
- [OPEN-010 — Separação entre intenção e mecanismos técnicos](open-questions/OPEN-010.md)
- [OPEN-011 — Composição de capacidades heterogêneas](open-questions/OPEN-011.md)
- [OPEN-012 — Isolamento e complexidade das capacidades geradas](open-questions/OPEN-012.md)
- [OPEN-013 — Identidade e privilégios de execução](open-questions/OPEN-013.md)
- [OPEN-014 — Orçamento de processamento e recuperação](open-questions/OPEN-014.md)
- [OPEN-015 — Disponibilidade e flexibilidade da inferência](open-questions/OPEN-015.md)
- [OPEN-016 — Acesso local e contrato externo do serviço](open-questions/OPEN-016.md)
- [OPEN-017 — Concorrência e previsibilidade de tarefas](open-questions/OPEN-017.md)
- [OPEN-018 — Operações e cenários atendidos pela primeira versão](open-questions/OPEN-018.md)
- [OPEN-019 — Tratamento de solicitações incompletas ou fora do escopo](open-questions/OPEN-019.md)
- [OPEN-020 — Garantias de validação antes de gerar e executar](open-questions/OPEN-020.md)
- [OPEN-021 — Cancelamento, tempo limite e falhas operacionais](open-questions/OPEN-021.md)
- [OPEN-022 — Geração versus execução automática do artefato](open-questions/OPEN-022.md)
- [OPEN-023 — Governança de capacidades publicadas](open-questions/OPEN-023.md)
- [OPEN-024 — Privacidade e permissão para informações externas](open-questions/OPEN-024.md)
- [OPEN-025 — Administração local, auditoria e manutenção da inferência](open-questions/OPEN-025.md)
- [OPEN-026 — Instalação, ambiente de operação e portabilidade](open-questions/OPEN-026.md)

## Critério de refinamento

Promover apenas após validar propósito, stakeholders, resultados, limites, premissas e referências, deixando todas as questões bloqueadoras resolvidas e os documentos necessários em `refined` ou `implemented`.

## Gate Charter → Scope

**BLOCKED.** OPEN-001 permanece pendente. As novas questões bloqueadoras registram divergências ou decisões do propósito ainda a confirmar. Questões estritamente técnicas são encaminhadas para Scope/Implementation e não definem detalhes técnicos no Charter.
