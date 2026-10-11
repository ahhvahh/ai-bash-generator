# OPEN-001 — Critérios mensuráveis de sucesso

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**ID:** OPEN-001  
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

Esta decisão fixa o número de testes e a meta para geração; **não define uma taxa de sucesso específica para reutilização de capacidades**. A decisão funcional do [OBJ-002](../objectives/OBJ-002.md) agora exige procurar e comparar capacidades existentes por finalidade, entradas, resultados esperados e restrições antes de gerar nova função; a meta de acerto permanece pendente.

## Decisão parcial aprovada — 11/10/2026

A regra de compatibilidade de [OBJ-002](../objectives/OBJ-002.md) está definida pelos ADRs existentes:

- [ADR-0008](../../../adr/catalogo/pinagem-versao-capability.md): reutilizar somente com igualdade exata de contrato lógico de entrada, propósito e contrato lógico de saída; manter a versão ativa selecionada durante toda a requisição; preservar versões anteriores.
- [ADR-0009](../../../adr/contratos/contrato-logico-e-stream.md): comparar contratos lógicos, sem confundir semântica com transporte.
- [ADR-0003](../../../adr/execucao/abi-stdout-stdin.md) e [ADR-0010](../../../adr/execucao/binding-invocacao.md): objetos JSON na fronteira das funções e adaptação encapsulada por capacidade.
- [ADR-0001](../../../adr/pipeline/pipeline-hibrido.md): gerar função quando não existir solução compatível e compor deterministicamente o script final.

Para avaliar reutilização, considerar os casos em que exista capacidade elegível exatamente compatível. Ausência de correspondência encaminha para geração e não constitui falha de reutilização. Casos incompatíveis devem verificar separadamente a ausência de reutilização indevida.

**Continuam pendentes:** seleção dos casos de teste e definição da meta de acerto da reutilização. Os 90% aprovados para geração não se aplicam automaticamente a esse objetivo.

A representação física final dos contratos e a canonicalização da comparação continuam pendências técnicas nos [registros existentes](../../../pendencias.md). Esta incorporação não resolve essas lacunas nem comprova implementação.

## Impacto

O sucesso da geração possui meta verificável e a regra funcional de comparação de capacidades do [OBJ-002](../objectives/OBJ-002.md) foi definida. Ainda faltam os 20 casos de geração e seus resultados esperados, além dos casos de teste e da meta de acerto próprios para a reutilização.

## Bloqueadora

**Sim.** Impede promover [PCH-001](../PCH-001.md), [OBJ-001](../objectives/OBJ-001.md) e [OBJ-002](../objectives/OBJ-002.md) para `refined`, bloqueando Charter → Scope.

## Próxima ação

1. Definir e aprovar previamente as 20 solicitações representativas, incluindo os resultados esperados de cada uma.
2. Definir os casos de teste e a meta de acerto da reutilização para [OBJ-002](../objectives/OBJ-002.md), incluindo casos com correspondência exata, sem correspondência e com diferenças nos contratos ou no propósito, sem presumir que os 90% de geração também se aplicam à reutilização.
3. Registrar as evidências das avaliações quando os testes forem realizados; não presumir execução ou aprovação de testes nesta decisão documental.
4. Reavaliar o gate Charter → Scope após tratar as demais pendências. A identidade operacional local, sem perfis de autorização próprios, foi estabelecida em [PCH-001](../PCH-001.md).
