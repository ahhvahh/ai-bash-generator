# Geração de Bash

![FLW](https://img.shields.io/badge/FLW-FLW--0001-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Descrever o fluxo desde a solicitação humana até um `BashArtifact` composto deterministicamente por functions resolvidas.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [MOD-0001 — Request Normalizer](../modulos/request-normalizer.md)
- [MOD-0002 — Capability Search](../modulos/capability-search.md)
- [MOD-0003 — Capability Function Generator](../modulos/capability-function-generator.md)
- [MOD-0004 — Validator](../modulos/validator.md)
- [MOD-0005 — Bash Output e Assembler](../modulos/bash-output.md)
- [CTR-0001 — Protobuf do pipeline](../contratos/pipeline-protobuf.md)
- [CTR-0005 — ABI JSON de functions](../contratos/function-json.md)
- [ADR-0013 — Sessão do gerador](../../adr/runtime/sessao-gerador.md)

## Gatilho

Solicitação aceita pelo serviço para geração de um artifact Bash.

## Pré-condições

- configuração válida;
- Request Normalizer disponível;
- dependências determinísticas do pipeline disponíveis.

## Fluxo principal

1. O Pipeline Manager atribui identidade interna à requisição.
2. O Request Normalizer produz `NormalizedRequest` com tasks estruturadas.
3. A aplicação valida contratos, referências e DAG.
4. Se o status for READY, Capability Search procura solução para cada task.
5. Cada capability compatível é pinada à versão avaliada e sua definição completa é carregada.
6. Para cada task sem capability compatível, o Capability Function Generator produz uma FUNCTION candidata.
7. O Validator valida DAG, contratos, versões, wrappers e functions geradas.
8. Com o conjunto resolvido válido, o Bash Output monta deterministicamente o script.
9. O assembler incorpora as functions e gera a função central de execução conforme o DAG.
10. Tasks independentes podem ser representadas para execução paralela; tasks dependentes aguardam seus predecessores.
11. Em fan-in, o Input Binder monta o objeto JSON da próxima function a partir dos resultados necessários.
12. O artifact é validado sintaticamente e materializado.
13. Nova FUNCTION aprovada para publicação segue o fluxo próprio de publicação, independente da materialização.
14. O serviço devolve o `BashArtifact` ao cliente conforme a API externa.

## Fluxos alternativos

### Informação ausente

Seguir FLW-0003. Capability Search não é executado.

### Todas as tasks já possuem capability

Nenhuma segunda inferência é necessária. O pipeline segue da resolução para validação e assembly.

### Capability ausente

Somente a task sem solução é enviada ao Capability Function Generator.

### Tasks independentes

Nós sem dependência entre si permanecem independentes no DAG. O assembler não cria dependências apenas para linearizar o script.

### Fan-in estrutural

Múltiplos resultados necessários por uma task são ligados pelo Input Binder. Isso não cria uma task nova.

### Transformação funcional de múltiplos resultados

Quando combinar resultados possui significado funcional próprio, essa transformação deve existir como task e capability explícitas.

## Falhas e tratamento

Erros de normalização, busca, geração de function, contrato, versão, policy, validação ou filesystem interrompem a etapa correspondente.

Falhas e cancelamento em branches paralelos ainda dependem da política operacional de concorrência a ser refinada.

## Resultado

`BashArtifact`, falha estruturada ou pedido por informação ausente.

## BLOCKED

O fluxo não pode atingir `refined` enquanto permanecerem abertos:

- pinagem final de versão do catálogo;
- isolamento e policy de functions;
- limites do gerador de capability;
- política de concorrência, buffering e falha em branches paralelos;
- contratos externos necessários ao retorno.

## Critérios de aceite

- LLM não monta o script final;
- task resolvida pelo catálogo não exige geração por LLM;
- toda capability chega ao assembler como function com ABI uniforme;
- dependências do DAG são preservadas;
- tasks independentes não são serializadas artificialmente;
- artifact só é materializado após validação válida;
- publicação de capability e materialização permanecem independentes.

## Implementação relacionada

A arquitetura-alvo descrita aqui ainda não foi verificada como comportamento integral do runtime atual.
