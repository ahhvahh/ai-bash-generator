# Bash Generator

![MOD](https://img.shields.io/badge/MOD-MOD--0003-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Selecionar, compor ou gerar capabilities e produzir um `GenerationPlan`; nunca produzir o arquivo Bash final diretamente.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0007 — Capabilities geradas](../../adr/geracao/capabilities-geradas.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0010 — Binding de invocação](../../adr/execucao/binding-invocacao.md)
- [ADR-0013 — Sessão do gerador](../../adr/runtime/sessao-gerador.md)
- [CTR-0001 — Protobuf](../contratos/pipeline-protobuf.md)
- [PRM-0002 — Prompt do gerador](../prompts/bash-generator.md)

## Responsabilidades

- preferir uma capability composta compatível;
- compor o menor conjunto compatível quando necessário;
- solicitar detalhes somente de candidatos relevantes;
- gerar somente comportamento ausente;
- finalizar com `GenerationPlan`;
- respeitar limites de turnos, tools e contexto.

## Entradas

`GeneratorTurnRequest` com request normalizado, candidatos e respostas de tools.

## Saídas

`GeneratorToolRequests` ou `GenerationPlan`.

## Interfaces e contratos

- [CTR-0001](../contratos/pipeline-protobuf.md)
- [CTR-0002 — MCP](../contratos/mcp.md)

## Restrições

Capability existente só pode ser usada depois de carregar sua definição completa. Novas capabilities geradas pelo LLM são FUNCTION.

**BLOCKED:** versão fixada, binding de invocação e orçamento de contexto ainda dependem de ADRs em refinamento.

## Critérios de aceite

- Não existe campo de script livre no plano.
- Tools passam pelo Orchestrator.
- Valores específicos da requisição ficam em bindings.
- O plano referencia apenas capabilities resolvidas ou geradas no próprio plano.

## Implementação relacionada

Referência histórica: `src/go/internal/pipeline/` e integração de inferência; não verificadas nesta adequação.
