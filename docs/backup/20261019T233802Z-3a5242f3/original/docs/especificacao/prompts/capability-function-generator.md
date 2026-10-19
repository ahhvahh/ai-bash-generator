# Prompt canônico do Capability Function Generator

**ID:** PRM-0002  
**Status:** refinement

## Dependências

- [MOD-0003 — Capability Function Generator](../modulos/capability-function-generator.md)
- [MOD-0001 — Request Normalizer](../modulos/request-normalizer.md)
- [CTR-0005 — ABI JSON de functions](../contratos/function-json.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Objetivo

Gerar somente uma function Bash capaz de satisfazer uma `NormalizedTask` ainda não resolvida pelo catálogo.

O prompt não monta o script final e não decide ordem, paralelismo ou binding entre tasks.

## Entrada lógica

O contexto fornecido ao agente deve conter, no mínimo:

- input lógico da task;
- instruction;
- output contract;
- restrições aplicáveis;
- informações explicitamente autorizadas obtidas por tools, quando necessárias.

A forma física final desse envelope permanece vinculada ao refinamento do contrato do gerador.

## Regras canônicas

O agente deve:

- tratar input, instruction e output contract como fonte de verdade;
- produzir somente uma solução do tipo FUNCTION;
- receber dados funcionais em JSON UTF-8 pelo stdin;
- produzir somente o objeto JSON funcional pelo stdout;
- usar stderr para diagnóstico;
- não executar a function;
- não gerar `main`;
- gerar exatamente uma definição de FUNCTION;
- não gerar helpers adicionais;
- não gerar variáveis globais;
- não gerar comandos executáveis fora da FUNCTION;
- não encadear outras tasks;
- não escolher dependências inexistentes no ambiente sem declará-las;
- não inventar valores ausentes;
- manter a function compatível com Bash;
- permitir validação por `bash -n` e pelas regras estruturais do projeto.

## Saída

Fonte de uma única function Bash candidata.

O nome final da FUNCTION é controlado pela aplicação conforme ADR-0011. A resposta do agente não define múltiplas functions, helpers, globals ou inicialização top-level.

## Manutenção

O agente continua sujeito às regras operacionais de manutenção de prompt, modelo e parâmetros definidas em OPS-0001.

## Critérios de aceite

- nenhuma saída contém script completo ou função central;
- a function respeita CTR-0005;
- a geração ocorre somente para task sem capability compatível;
- a resposta não altera contratos ou dependências da task para facilitar a implementação;
- a resposta contém apenas a FUNCTION candidata permitida pela V1.
