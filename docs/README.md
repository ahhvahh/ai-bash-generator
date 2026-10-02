# Documentação do ai-bash-gen

Esta é a raiz documental do projeto, organizada conforme o Architecture Documentation Pipeline — ADP 1.0.

## Pipeline documental

`Decisão → Desenho → Especificação → Desenvolvimento → Ativação`

A documentação desta branch foi reorganizada a partir do conteúdo anteriormente distribuído entre `docs/analysis/`, `docs/pipeline/`, `docs/AGENTS.md` e `docs/MCP.md`.

## Decisões arquiteturais

### Refinadas

- [ADR-0001 — Pipeline híbrido LLM e determinístico](adr/pipeline/pipeline-hibrido.md)
- [ADR-0002 — Protobuf e TextProto](adr/contratos/protobuf-e-textproto.md)
- [ADR-0003 — ABI stdout/stdin](adr/execucao/abi-stdout-stdin.md)
- [ADR-0004 — PostgreSQL e versões imutáveis de capabilities](adr/persistencia/catalogo-capabilities.md)
- [ADR-0005 — Orquestração e autorização de MCPs](adr/integracoes/orquestracao-mcp.md)
- [ADR-0006 — Publicação e materialização independentes](adr/pipeline/publicacao-materializacao.md)
- [ADR-0007 — Capabilities geradas como FUNCTION](adr/geracao/capabilities-geradas.md)

### Em refinamento

- [ADR-0008 — Identidade e pinagem de versão da capability](adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico separado do encoding](adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding determinístico de invocação](adr/execucao/binding-invocacao.md)
- [ADR-0011 — Isolamento de functions geradas](adr/execucao/isolamento-functions.md)
- [ADR-0012 — Efeitos e autorização de capabilities](adr/seguranca/efeitos-capabilities.md)
- [ADR-0013 — Sessão e orçamento de contexto do gerador](adr/runtime/sessao-gerador.md)
- [ADR-0014 — Lifecycle de modelos](adr/runtime/lifecycle-modelos.md)
- [ADR-0015 — Protocolo externo do daemon](adr/api/protocolo-daemon.md)

## Desenhos

- [DSG-0001 — Pipeline de geração](desenho/pipeline-geracao.md) — `finalized`
- [DSG-0002 — Catálogo de capabilities](desenho/catalogo-capabilities.md) — `backlog`
- [DSG-0003 — Runtime do daemon](desenho/runtime-daemon.md) — `backlog`

## Especificações

### Módulos
- [MOD-0001 — Request Normalizer](especificacao/modulos/request-normalizer.md)
- [MOD-0002 — Capability Search](especificacao/modulos/capability-search.md)
- [MOD-0003 — Bash Generator](especificacao/modulos/bash-generator.md)
- [MOD-0004 — Validator](especificacao/modulos/validator.md)
- [MOD-0005 — Bash Output](especificacao/modulos/bash-output.md)
- [MOD-0006 — Tool/MCP Orchestrator](especificacao/modulos/tool-orchestrator.md)

### Contratos
- [CTR-0001 — Contratos Protobuf do pipeline](especificacao/contratos/pipeline-protobuf.md)
- [CTR-0002 — MCP](especificacao/contratos/mcp.md)
- [CTR-0003 — Configuração de agentes](especificacao/contratos/agentes.md)
- [CTR-0004 — API externa do daemon](especificacao/contratos/api-daemon.md)

### Persistência e integrações
- [PST-0001 — Catálogo de capabilities](especificacao/persistencia/catalogo-capabilities.md)
- [INT-0001 — Google Mail MCP](especificacao/integracoes/google-mail.md)

### Prompts
- [PRM-0001 — Request Normalizer](especificacao/prompts/request-normalizer.md)
- [PRM-0002 — Bash Generator](especificacao/prompts/bash-generator.md)

### Fluxos
- [FLW-0001 — Geração de Bash](especificacao/fluxos/geracao-bash.md)
- [FLW-0002 — Publicação de capability](especificacao/fluxos/publicacao-capability.md)
- [FLW-0003 — Informação obrigatória ausente](especificacao/fluxos/informacao-ausente.md)
- [FLW-0004 — Correção após falha de validação](especificacao/fluxos/correcao-validacao.md)
- [FLW-0005 — Cancelamento e timeout](especificacao/fluxos/cancelamento-timeout.md)
- [FLW-0006 — Execução futura do artifact](especificacao/fluxos/execucao-artifact.md)

## Pendências

As lacunas, gates bloqueados e decisões ainda necessárias estão consolidados em [pendencias.md](pendencias.md).

## Implementação relacionada

Referências existentes para `proto/` e `src/` são apenas referências de rastreabilidade. Esta adequação documental não usou arquivos fora de `/docs` como fonte de validação.
