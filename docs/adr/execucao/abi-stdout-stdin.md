# ABI JSON por stdin e stdout entre functions

![ADR](https://img.shields.io/badge/ADR-ADR--0003-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-2-6e7781?style=flat-square)

## Contexto

Capabilities precisam ser compostas em um artifact Bash previsível. As tarefas trabalham com objetos estruturados, listas e valores escalares, inclusive quando partes independentes do DAG são executadas em paralelo.

## Problema

É necessário definir um formato único de dados entre functions que seja estruturado, simples de validar e compatível com Bash, sem obrigar o assembler a conhecer a implementação interna de cada capability.

Também é necessário permitir fan-out e fan-in sem criar capabilities artificiais apenas para roteamento de dados.

## Restrições

- cada processo possui um único stdin;
- stdout funcional e stderr de diagnóstico são canais distintos;
- o payload precisa representar objetos, listas, strings, números, booleanos e null;
- o transporte deve ser adequado a pipes e ferramentas usuais do ambiente Bash;
- dependências e paralelismo são definidos pelo DAG da requisição;
- roteamento de dados não representa comportamento de negócio.

## Opções consideradas

### Variáveis Bash como transporte principal

Não fornecem um contrato estrutural suficiente e criam problemas de escaping e tamanho.

### MessagePack

Compacto e estruturado, porém binário e inadequado como ABI principal de funções Bash.

### JSON UTF-8 por stdin e stdout

Textual, estruturado, amplamente suportado e compatível com pipes e ferramentas de processamento JSON.

## Decisão

Adotar JSON UTF-8 como formato canônico de payload entre functions.

Cada function resolvida:

- recebe exatamente um objeto JSON lógico pelo stdin;
- produz exatamente um objeto JSON lógico pelo stdout;
- escreve diagnóstico somente em stderr;
- retorna `0` em sucesso e código diferente de zero em falha, conforme contrato de erro aplicável.

A `NormalizedRequest` forma um DAG. Tarefas sem dependência entre si podem ser preparadas para execução paralela.

Quando uma tarefa possui múltiplos `result_ref`, um **Input Binder determinístico** monta o único objeto JSON de entrada esperado pela function a partir dos resultados predecessores.

O Input Binder é infraestrutura do pipeline. Ele não cria uma capability nem uma task adicional, salvo quando houver transformação funcional real solicitada pelo fluxo.

## Justificativa

JSON mantém os dados estruturados sem introduzir um protocolo binário pouco natural para Bash. A separação entre DAG, binding de dados e funções evita criar etapas artificiais apenas para viabilizar fan-in ou fan-out.

## Consequências

- a limitação anterior de pipeline exclusivamente linear deixa de existir;
- o scheduler pode liberar tarefas independentes em paralelo;
- o assembler precisa preservar dependências do DAG e gerar o binding determinístico dos objetos JSON;
- implementations externas podem usar outros formatos internamente, mas seu wrapper de capability deve adaptar a fronteira para JSON;
- detalhes de buffering, materialização temporária e limite de concorrência pertencem à especificação de execução e permanecem sujeitos a refinamento.

## Dependências

- [ADR-0001](../pipeline/pipeline-hibrido.md)

## Critérios de validação

- stdin funcional contém JSON UTF-8 válido;
- stdout de sucesso contém somente o JSON funcional esperado;
- logs e diagnósticos não contaminam stdout;
- contratos de produtor e consumidor são compatíveis antes da composição;
- tarefas independentes não recebem dependências artificiais;
- fan-in monta um único objeto de entrada sem criar capability de roteamento;
- falha de uma function é observável por código de saída e stderr.
