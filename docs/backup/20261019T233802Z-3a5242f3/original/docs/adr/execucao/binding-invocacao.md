# Binding determinístico por função de capability

![ADR](https://img.shields.io/badge/ADR-ADR--0010-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

Uma capability pode ser implementada por FUNCTION, SCRIPT, APPLICATION ou SERVICE. O assembler precisa compor todas essas soluções sem inferir convenções de linha de comando.

## Problema

Se o assembler receber diretamente uma implementação externa, um campo lógico como `path` poderia virar argumento posicional, flag, variável de ambiente, stdin ou outra convenção. Essa decisão não pode ser inferida durante a montagem do script.

## Restrições

- o assembler deve ser determinístico;
- todas as tasks chegam com entrada e saída lógicas estruturadas;
- a ABI entre funções é JSON UTF-8;
- detalhes de invocation pertencem à capability versionada.

## Opções consideradas

### Binding genérico no assembler

Exigiria modelar posição, flag, boolean, environment, repetição e demais convenções para cada comando externo.

### Wrapper Bash por capability

Cada capability fornece uma função Bash que adapta a ABI canônica para sua implementation concreta.

## Decisão

Toda capability resolvida deve expor uma **função Bash reutilizável** compatível com a ABI definida pelo ADR-0003.

Para o assembler não existe diferença operacional entre FUNCTION, SCRIPT, APPLICATION ou SERVICE.

O wrapper da capability é responsável por:

- receber o objeto JSON de entrada;
- adaptar os campos para a implementation concreta;
- executar ou invocar a implementation;
- converter o resultado para o objeto JSON de saída;
- preservar stderr para diagnóstico;
- propagar sucesso ou falha pelo código de saída.

O assembler somente encadeia functions e não transforma campos lógicos diretamente em flags, argumentos posicionais, environment ou protocolos externos.

## Justificativa

A adaptação fica junto da versão da capability, onde pode ser validada e reutilizada. O script final passa a ser composto por uma interface homogênea.

## Consequências

- o catálogo precisa entregar, junto da versão resolvida, o wrapper funcional necessário à composição;
- alterações na forma de invocar uma aplicação ou script exigem nova versão da capability quando modificarem o wrapper;
- o Bash Output não precisa manter um sistema genérico de binding de CLI;
- novas capabilities produzidas por LLM continuam sendo FUNCTION conforme ADR-0007.

## Dependências

- [ADR-0003](abi-stdout-stdin.md)
- [ADR-0007](../geracao/capabilities-geradas.md)
- [ADR-0009](../contratos/contrato-logico-e-stream.md)

## Critérios de validação

- o assembler invoca somente functions com ABI canônica;
- uma APPLICATION ou SCRIPT não exige lógica específica no assembler;
- valores da task continuam sendo dados estruturados até entrarem no wrapper;
- quoting e convenções da implementação ficam encapsulados no wrapper;
- uma capability resolvida sem wrapper compatível é rejeitada.
