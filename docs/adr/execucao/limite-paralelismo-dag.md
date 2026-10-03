# Limite de paralelismo do DAG na V1

![ADR](https://img.shields.io/badge/ADR-ADR--0016-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

O `BashArtifact` representa as tasks como um DAG. Tasks independentes podem executar em paralelo e tasks dependentes aguardam seus predecessores.

Sem um limite explícito, uma execução poderia iniciar processos em quantidade indefinida quando várias tasks estivessem simultaneamente prontas.

## Problema

A V1 precisa definir quantas tasks podem estar em execução ao mesmo tempo dentro de um mesmo `BashArtifact`.

Esse limite precisa ser conhecido pelo assembler e pelo runtime do artifact para que dois desenvolvedores não adotem políticas distintas.

## Restrições

- o paralelismo deriva somente do DAG;
- uma task só pode executar quando suas dependências estiverem satisfeitas;
- o limite não autoriza ignorar dependências;
- esta decisão não define ainda buffering de outputs, ordem entre múltiplas tasks prontas ou política completa de falha/cancelamento.

## Opções consideradas

### Execução sem limite fixo

Inicia todas as tasks prontas simultaneamente.

Permite maior paralelismo, porém pode consumir processos e recursos do host sem limite previsível.

### Limite de quatro execuções simultâneas

Permite paralelismo suficiente para a V1 mantendo um teto simples e previsível de processos concorrentes.

## Decisão

Na V1, cada execução de um `BashArtifact` pode manter no máximo **4 tasks em execução simultaneamente**.

Se existirem menos de quatro tasks prontas, somente as disponíveis podem ser iniciadas.

Quando quatro tasks já estiverem em execução, qualquer nova task pronta deve aguardar a liberação de uma vaga.

Este ADR define somente o limite máximo de concorrência. A regra de seleção quando houver mais tasks prontas do que vagas, a estratégia de buffering/materialização de resultados e a política de falha/cancelamento permanecem decisões separadas.

## Justificativa

O limite de quatro mantém o comportamento simples e previsível para a V1 e evita criação ilimitada de processos sem eliminar o benefício do paralelismo do DAG.

## Consequências

- o assembler deve gerar controle que nunca ultrapasse quatro tasks simultâneas;
- dependências continuam determinando quando uma task se torna elegível;
- a quinta task pronta, e as seguintes, aguardam uma vaga;
- o limite é aplicado por execução do artifact;
- a documentação de concorrência ainda permanece parcialmente bloqueada pelas regras de scheduling, buffering e falha.

## Dependências

- [ADR-0001 — Pipeline híbrido](../pipeline/pipeline-hibrido.md)
- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)

## Critérios de validação

- nenhuma execução do artifact mantém mais de quatro tasks simultaneamente em execução;
- task dependente não inicia antes da conclusão dos predecessores necessários;
- com menos de quatro tasks prontas, não são criadas tasks artificiais para completar o limite;
- o limite de quatro não é confundido com regra de ordenação entre tasks prontas.
