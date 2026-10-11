# OPEN-001 — Critérios mensuráveis de sucesso

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**ID:** OPEN-001  
**Status:** `refinement`  
**Version:** `v1`  
**Evidência:** `DOCUMENTED` para a meta aprovada; critérios restantes em `refinement`.

## Pergunta

Quais casos de uso, indicadores e metas mínimas demonstrarão que os objetivos de geração e de reutilização foram alcançados?

## Contexto

O [README do projeto](../../../../README.md) apresenta funcionalidades e testes, mas não estabelece uma baseline única de metas de qualidade, desempenho e aprovação para o Charter.

## Decisão parcial aprovada — 10/10/2026

Para o objetivo de geração ([OBJ-001](../objectives/OBJ-001.md)), adotar uma avaliação composta por **20 solicitações de teste**, com taxa mínima de sucesso de **90%**, correspondente a **pelo menos 18 solicitações aprovadas**.

Uma solicitação somente é aprovada quando **ambos** os critérios forem satisfeitos:

1. o script Bash gerado tem sintaxe válida;
2. o script atende à finalidade descrita na solicitação, conforme resultados esperados estabelecidos previamente para o caso.

**Cálculo:** taxa de sucesso = (quantidade de solicitações aprovadas ÷ 20) × 100. Uma falha em qualquer um dos dois critérios reprova a solicitação.

**Evidências por solicitação:** registrar a descrição do pedido, resultado esperado, artefato produzido ou sua identificação, avaliação da sintaxe, avaliação do atendimento à finalidade, resultado aprovado/reprovado e justificativa para eventual reprovação. Os scripts gerados **não são executados** por este critério. A revisão estática da finalidade não comprova integralmente o comportamento em execução.

Esta decisão fixa o número de testes e a meta para geração; **não define uma taxa de sucesso específica para reutilização de capacidades**. A decisão funcional do [OBJ-002](../objectives/OBJ-002.md) agora exige procurar e comparar capacidades existentes por finalidade, entradas, resultados esperados e restrições antes de gerar nova função; a meta numérica permanece pendente.

## Impacto

O sucesso da geração possui meta verificável e a regra funcional de comparação de capacidades do [OBJ-002](../objectives/OBJ-002.md) foi definida. Ainda faltam os 20 casos e seus resultados esperados e uma meta quantitativa própria para a reutilização.

## Bloqueadora

**Sim.** Impede promover [PCH-001](../PCH-001.md), [OBJ-001](../objectives/OBJ-001.md) e [OBJ-002](../objectives/OBJ-002.md) para `refined`, bloqueando Charter → Scope.

## Próxima ação

1. Definir e aprovar previamente as 20 solicitações representativas, incluindo os resultados esperados de cada uma.
2. Definir a meta mensurável de reutilização de capacidades para [OBJ-002](../objectives/OBJ-002.md), sem presumir que os 90% de geração também se aplicam à reutilização.
3. Registrar as evidências das avaliações quando os testes forem realizados; não presumir execução ou aprovação de testes nesta decisão documental.
4. Reavaliar o gate Charter → Scope após tratar as demais pendências. A identidade operacional local, sem perfis de autorização próprios, foi estabelecida em [PCH-001](../PCH-001.md).
