# OPEN-015 — Disponibilidade e flexibilidade da inferência

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Que comportamento de disponibilidade deve ser garantido quando um mecanismo de inferência estiver ausente, indisponível ou for substituído?

## Contexto para refinamento

O processamento local pode dispor de recursos para apenas uma instância de inferência de cada vez. Também foi considerada a utilização de modelos especializados, com eventual troca entre operações, o que pode afetar latência e disponibilidade. A decisão de produto necessária é definir os níveis de disponibilidade e continuidade exigidos, sem escolher a arquitetura dos modelos.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- O resultado deve permanecer disponível mesmo quando o mecanismo preferido de inferência estiver indisponível?
- Quais limites de espera e critérios de degradação são aceitáveis para operação local?
- A flexibilidade de escolher mecanismos diferentes é requisito inicial ou evolução opcional?

## Impacto

Relaciona-se à exigência de operação offline e ao limite de recursos de CON-001/CON-002.

## Bloqueadora

Sim — é necessário especificar o mínimo garantido para o funcionamento offline.

## Próxima ação

Revalidar o comportamento esperado com CON-001/ASM-001; deixar gerenciamento e recarga de modelos para Implementation.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [CON-001](../constraints/CON-001.md)
- [CON-002](../constraints/CON-002.md)
- [ASM-001](../assumptions/ASM-001.md)
