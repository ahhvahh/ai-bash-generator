# Pipeline híbrido com interpretação LLM e composição determinística

![ADR](https://img.shields.io/badge/ADR-ADR--0001-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-2-6e7781?style=flat-square)

## Contexto

O processamento possui etapas que exigem interpretação semântica e etapas que podem ser executadas deterministicamente.

A `NormalizedRequest` descreve tarefas por entrada lógica estruturada, instrução e contrato de saída. Capabilities reutilizáveis resolvem essas tarefas por meio de funções Bash padronizadas.

## Problema

Usar LLM para interpretar a solicitação, escolher ou criar soluções e também montar o script final aumenta variabilidade, contexto e superfície de erro.

Depois que cada tarefa possui uma função capaz de satisfazer seus contratos, o encadeamento não exige inferência.

## Restrições

- informação obrigatória ausente não pode ser inventada;
- busca, validação, ordenação do DAG e materialização devem ser determinísticas;
- o script final não é executado pelo processo de geração;
- uma capability ausente pode exigir geração semântica de uma nova FUNCTION;
- toda função resolvida deve obedecer à ABI definida pelo ADR-0003.

## Opções consideradas

### LLM para gerar o script completo

Flexível, porém repete interpretação já realizada pelo normalizador e torna o encadeamento variável.

### LLM somente para normalização e criação de capability ausente

O modelo interpreta a solicitação e, quando necessário, produz uma FUNCTION para uma tarefa sem solução catalogada. Busca, resolução, composição, validação e materialização permanecem determinísticas.

## Decisão

Usar LLM somente para:

1. transformar a solicitação humana em `NormalizedRequest`;
2. gerar uma nova capability do tipo `FUNCTION` quando uma tarefa não possuir solução compatível no catálogo.

A composição do script final não usa LLM.

Depois que todas as tarefas estiverem resolvidas para funções, a aplicação:

1. valida contratos e dependências;
2. organiza o DAG;
3. monta deterministicamente a função central de execução;
4. materializa o `BashArtifact`.

## Justificativa

A LLM permanece nas etapas que exigem interpretação ou criação semântica. O encadeamento de funções já conhecidas é um problema estrutural e verificável, portanto deve ser resolvido por código determinístico.

## Consequências

- o antigo Bash Generator deixa de gerar o script completo e passa a gerar somente FUNCTION para tarefa não resolvida;
- o Bash Output assume composição determinística e materialização;
- o catálogo pode reutilizar FUNCTION, SCRIPT, APPLICATION ou SERVICE desde que a capability exponha uma função Bash compatível com a ABI;
- o custo de inferência cai quando todas as tarefas já possuem capabilities compatíveis;
- paralelismo é derivado do DAG, não decidido pela LLM.

## Dependências

- nenhuma

## Critérios de validação

- somente normalização e geração de capability ausente dependem de inferência;
- uma requisição totalmente resolvida pelo catálogo pode chegar ao artifact sem segunda inferência;
- o script final deriva apenas das tarefas e functions validadas;
- a aplicação, e não a LLM, determina dependências prontas para execução e composição;
- informação ausente interrompe o pipeline antes da busca.
