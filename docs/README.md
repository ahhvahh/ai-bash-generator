# Documentação do ai-bash-gen

Esta é a raiz documental do projeto, organizada conforme o Architecture Documentation Pipeline — ADP 1.0.

## Pipeline documental

`Decisão → Desenho → Especificação → Desenvolvimento → Ativação`

## Decisões arquiteturais

### Refinadas

- [ADR-0001 — Pipeline híbrido com composição determinística](adr/pipeline/pipeline-hibrido.md)
- [ADR-0002 — Protobuf e TextProto](adr/contratos/protobuf-e-textproto.md)
- [ADR-0003 — ABI JSON por stdin/stdout](adr/execucao/abi-stdout-stdin.md)
- [ADR-0004 — PostgreSQL e versões imutáveis de capabilities](adr/persistencia/catalogo-capabilities.md)
- [ADR-0005 — Orquestração e autorização de MCPs](adr/integracoes/orquestracao-mcp.md)
- [ADR-0006 — Publicação e materialização independentes](adr/pipeline/publicacao-materializacao.md)
- [ADR-0007 — Capabilities geradas como FUNCTION](adr/geracao/capabilities-geradas.md)
- [ADR-0008 — Matching exato e pinagem de versão da capability](adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico separado do transporte](adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função de capability](adr/execucao/binding-invocacao.md)
- [ADR-0011 — Isolamento de functions geradas](adr/execucao/isolamento-functions.md)
- [ADR-0012 — Controle de acesso pelo ambiente de execução](adr/seguranca/efeitos-capabilities.md)

### Em refinamento

- [ADR-0013 — Sessão e orçamento do gerador de capability](adr/runtime/sessao-gerador.md)
- [ADR-0014 — Lifecycle de modelos](adr/runtime/lifecycle-modelos.md)
- [ADR-0015 — Protocolo externo do daemon](adr/api/protocolo-daemon.md)

## Desenhos

- [DSG-0001 — Pipeline de geração](desenho/pipeline-geracao.md) — `finalized`
- [DSG-0002 — Catálogo de capabilities](desenho/catalogo-capabilities.md) — `finalized`
- [DSG-0003 — Runtime do daemon](desenho/runtime-daemon.md) — `backlog`

## Especificações

### Módulos

- [MOD-0001 — Request Normalizer](especificacao/modulos/request-normalizer.md)
- [MOD-0002 — Capability Search](especificacao/modulos/capability-search.md)
- [MOD-0003 — Capability Function Generator](especificacao/modulos/capability-function-generator.md)
- [MOD-0004 — Validator](especificacao/modulos/validator.md)
- [MOD-0005 — Bash Output e Assembler](especificacao/modulos/bash-output.md)
- [MOD-0006 — Tool/MCP Orchestrator](especificacao/modulos/tool-orchestrator.md)

### Contratos

- [CTR-0001 — Contratos Protobuf do pipeline](especificacao/contratos/pipeline-protobuf.md)
- [CTR-0002 — MCP](especificacao/contratos/mcp.md)
- [CTR-0003 — Configuração de agentes](especificacao/contratos/agentes.md)
- [CTR-0004 — API externa do daemon](especificacao/contratos/api-daemon.md)
- [CTR-0005 — ABI JSON de functions](especificacao/contratos/function-json.md)

### Persistência e integrações

- [PST-0001 — Catálogo de capabilities](especificacao/persistencia/catalogo-capabilities.md)
- [INT-0001 — Google Mail MCP](especificacao/integracoes/google-mail.md)

### Prompts

- [PRM-0001 — Request Normalizer](especificacao/prompts/request-normalizer.md)
- [PRM-0002 — Capability Function Generator](especificacao/prompts/capability-function-generator.md)

### Runtime e operação

- [OPS-0001 — Manutenção da inferência](especificacao/runtime/manutencao-inferencia.md)

### Fluxos

- [FLW-0001 — Geração de Bash](especificacao/fluxos/geracao-bash.md)
- [FLW-0002 — Publicação de capability](especificacao/fluxos/publicacao-capability.md)
- [FLW-0003 — Informação obrigatória ausente](especificacao/fluxos/informacao-ausente.md)
- [FLW-0004 — Correção após falha de validação](especificacao/fluxos/correcao-validacao.md)
- [FLW-0005 — Cancelamento e timeout](especificacao/fluxos/cancelamento-timeout.md)
- [FLW-0006 — Execução futura do artifact](especificacao/fluxos/execucao-artifact.md)

## Arquitetura funcional atual documentada

O fluxo-alvo é:

`UserRequest → LLM normaliza → tasks estruturadas → busca capabilities → gera FUNCTION somente quando faltar solução → valida DAG/functions → assembler determinístico → BashArtifact`

O plano de controle permanece Protobuf/TextProto. O payload funcional entre functions no artifact é JSON UTF-8.

Tasks independentes permanecem independentes no DAG; paralelismo não é decidido pela LLM.

Capability Search reutiliza somente funções cujo contrato de entrada, contrato de saída e propósito coincidam exatamente. A versão ativa mais recente é retornada por `capability_version_id` e permanece pinada durante a requisição. Refatorações de performance criam novas versões imutáveis da mesma capability.

A autorização da execução pertence ao usuário/processo e ao ambiente que executam o `BashArtifact`. Catálogo, LLM e assembler não concedem privilégios; aplicações externas somente podem ser utilizadas quando estiverem disponíveis e acessíveis ao executor.

Na V1, capabilities geradas são funções pontuais: exatamente uma FUNCTION por capability, sem helpers, globals ou execução top-level. O escopo inicial cobre operações simples de sistema, como comandos, diretórios, contagem de arquivos e consulta de CPU, memória, armazenamento e rede.

## Pendências

As lacunas, gates bloqueados e decisões ainda necessárias estão consolidados em [pendencias.md](pendencias.md).

## Implementação relacionada

A documentação distingue comportamento implementado de arquitetura-alvo. As mudanças de normalização estruturada, geração apenas de FUNCTION e assembly determinístico ainda precisam ser reconciliadas com a implementação antes de os documentos correspondentes avançarem para estados de desenvolvimento.
