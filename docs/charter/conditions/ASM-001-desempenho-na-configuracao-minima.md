# ASM-001 — Desempenho na configuração mínima

![Tipo: ASM](../../assets/documentation-style/badges/badge-type-asm.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**Evidência:** `DOCUMENTED` como alvo; desempenho medido `UNKNOWN`.

## Premissa

A configuração mínima obrigatória de quatro CPUs e 8 GB de RAM, registrada em [CON-002](CON-002-recursos-minimos-de-execucao.md), será suficiente para oferecer desempenho aceitável nas funcionalidades locais previstas. Trata-se de hipótese ainda não comprovada por medições.

## Evidência disponível

A configuração em vigor é a restrição de quatro CPUs e 8 GB de RAM documentada em [CON-002](CON-002-recursos-minimos-de-execucao.md). Em planejamento anterior, foi considerado o patamar de dois núcleos e 8 GB de RAM, agora superado para a baseline do Charter. Nenhuma medição de latência ou qualidade foi apresentada para comprovar suficiência; a comparação entre configurações é apenas um assunto de validação, não uma restrição concorrente.

## Risco se falsa

A solução poderá apresentar latência excessiva, saturação de memória/CPU ou qualidade insuficiente no modo offline, mesmo respeitando a configuração obrigatória. Uso opcional de APIs externas não comprova a viabilidade offline.

## Necessidade de Discovery

Medir consumo de recursos, tempo de resposta e qualidade das solicitações representativas no modo offline sobre a configuração mínima de [CON-002](CON-002-recursos-minimos-de-execucao.md). Os indicadores e casos de aceitação precisam ser completados em [OPEN-001](../open-questions/OPEN-001-criterios-mensuraveis-de-sucesso.md).

## Itens afetados

[PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md), [CON-001](CON-001-operacao-offline-e-apis-externas-opcionais.md), [CON-002](CON-002-recursos-minimos-de-execucao.md), [OBJ-001](../objectives/OBJ-001-gerar-scripts-bash-a-partir-de-linguagem-natural.md), [OPEN-001](../open-questions/OPEN-001-criterios-mensuraveis-de-sucesso.md).
