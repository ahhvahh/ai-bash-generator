# Capability Function Generator

![MOD](https://img.shields.io/badge/MOD-MOD--0003-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Gerar uma nova capability do tipo `FUNCTION` para uma única task que não possua solução compatível no catálogo.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0001 — Pipeline híbrido](../../adr/pipeline/pipeline-hibrido.md)
- [ADR-0003 — ABI JSON](../../adr/execucao/abi-stdout-stdin.md)
- [ADR-0007 — Capabilities geradas como FUNCTION](../../adr/geracao/capabilities-geradas.md)
- [ADR-0011 — Isolamento de functions](../../adr/execucao/isolamento-functions.md)
- [ADR-0013 — Sessão do gerador](../../adr/runtime/sessao-gerador.md)
- [CTR-0005 — ABI JSON de functions](../contratos/function-json.md)
- [PRM-0002 — Prompt do gerador de function](../prompts/capability-function-generator.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Responsabilidades

- receber uma task não resolvida;
- usar input, instruction e output contract como fonte de verdade;
- produzir somente uma solução do tipo FUNCTION;
- obedecer à ABI JSON;
- não montar o script final;
- não alterar o DAG;
- não inventar valores ausentes;
- solicitar tools somente pelo Tool/MCP Orchestrator quando permitido;
- retornar artefato suficiente para validação e eventual publicação como capability candidate.

## Entradas

Uma task não resolvida, seus contratos e o contexto mínimo autorizado para gerar a função.

O gerador não precisa receber o conjunto completo de functions já resolvidas apenas para encadear o script.

## Saídas

Definição de uma nova capability FUNCTION candidata, incluindo fonte Bash da função e contratos necessários para validação.

O nome final, namespace e regras estruturais da função seguem ADR-0011 e contratos associados.

## Restrições

- nunca retorna script completo;
- nunca retorna APPLICATION, SCRIPT ou SERVICE novos;
- não executa a function;
- não ativa automaticamente a capability;
- stdout funcional da function gerada deve obedecer ao CTR-0005.

## BLOCKED

ADR-0011 e ADR-0013 ainda precisam ser refinados antes desta especificação atingir `refined`.

## Critérios de aceite

- uma task já resolvida pelo catálogo não chama este módulo;
- a saída representa somente uma FUNCTION candidata;
- a function aceita o objeto de input esperado e produz o objeto de output esperado;
- nenhuma lógica de montagem do DAG é delegada à LLM;
- a saída pode ser validada antes de publicação ou uso.

## Implementação relacionada

A implementação atual ainda contém um gerador de Bash completo e não representa esta arquitetura-alvo.
