# Revisão de Arquitetura

Esta revisão acompanha decisões arquiteturais do pipeline do `ai-bash-gen`.

Diagramas: [../pipeline/SEQUENCE_DIAGRAMS.md](../pipeline/SEQUENCE_DIAGRAMS.md)

Contrato: [../../proto/ai_bash_gen/v1/pipeline.proto](../../proto/ai_bash_gen/v1/pipeline.proto)

> **Status RESOLVIDO** significa que a regra, o contrato e a responsabilidade arquitetural foram definidos. A implementação em Go/PostgreSQL ainda faz parte da fase de desenvolvimento.

## Resumo atual

```text
BLOCKER   8 resolvidos / 0 abertos
HIGH      9 resolvidos / 0 abertos
MEDIUM    4 resolvidos / 1 aberto
```

O único ponto ainda aberto exige benchmark real com os modelos/tokenizers utilizados.

---

## ✅ RESOLVIDO — BLOCKER-01 — ABI entre capabilities

### Decisão

Composição segue o padrão Unix:

```text
producer stdout -> consumer stdin
```

Regras:

```text
stdout   resultado funcional
stdin    entrada do estágio anterior
stderr   diagnóstico
exit 0   sucesso
exit !=0 falha
```

`result_ref` representa a conexão lógica entre o stdout produtor e o stdin consumidor.

O conteúdo é validado por `DataContract`.

### Topologia inicial

Uma chamada possui um único stdin.

A primeira versão suporta diretamente pipelines lineares:

```text
A | B | C
```

Fan-out/fan-in exige capability explícita de `tee`, merge/join ou materialização intermediária.

---

## ✅ RESOLVIDO — BLOCKER-02 — Duas fontes de verdade

### Problema anterior

`GenerationResult` continha:

```text
calls
generated_capabilities
script
```

O plano e o script poderiam divergir.

### Decisão

O LLM produz somente:

```text
GenerationPlan
```

O campo `script` foi removido do contrato.

Fluxo:

```text
GenerationPlan
      |
      v
Validation
      |
      v
deterministic Bash Output
      |
      v
BashArtifact
```

O arquivo Bash é derivado deterministicamente do plano e das versões de capabilities carregadas.

---

## ✅ RESOLVIDO — BLOCKER-03 — Protocolo de turnos de get_capability

### Decisão

Foi formalizado um tool loop:

```text
GeneratorTurnRequest
        |
        v
GeneratorTurnResult
        |
        +--> GeneratorToolRequests
        |       |
        |       v
        |   Tool Orchestrator
        |       |
        |       v
        |   GeneratorToolResponse
        |       |
        +-------+
        |
        v
GenerationPlan
```

Mensagens adicionadas:

```text
GeneratorTurnRequest
GeneratorTurnResult
GeneratorToolRequest
GeneratorToolRequests
GeneratorToolResponse
ToolError
```

`get_capability` é um tipo explícito de tool request.

MCPs de geração também podem utilizar:

```text
McpToolRequest
ToolPayload
McpToolResult
```

O `ai-bash-gen` é o dono do loop e da autorização. O `llama-server` é somente o motor de inferência.

---

## ✅ RESOLVIDO — BLOCKER-04 — Sistema de tipos estruturados

### Decisão

Strings livres como:

```text
"type": "table"
```

não são mais o contrato canônico.

Foram definidos:

```text
DataKind
DataContract
FieldSchema
StreamEncoding
ParameterContract
CapabilityInterface
```

Exemplo:

```text
kind: TABLE
fields: name(TEXT), size(INTEGER), type(TEXT)
encoding: JSON_LINES
```

A aplicação valida deterministicamente:

- tipo;
- campos;
- obrigatoriedade;
- encoding;
- stdin/stdout;
- argumentos.

FTS continua sendo apenas mecanismo de descoberta semântica.

---

## ✅ RESOLVIDO — BLOCKER-05 — Versionamento do catálogo

### Decisão

Separação:

```text
capability
    identidade lógica e campos de pesquisa

capability_version
    definição imutável
```

Cada versão possui:

```text
id
capability_id
version
status
contracts
implementation
dependencies
risk
checksum
fingerprint
```

`CapabilityDefinition` devolve:

```text
capability_version_id
version
checksum
```

Quando `get_capability(id)` não recebe versão, o catálogo resolve a versão ativa.

O FK composto garante que `active_version_id` pertença à capability correta.

Também existe garantia de no máximo uma versão ativa por capability.

---

## ✅ RESOLVIDO — BLOCKER-06 — Contrato por tipo de implementação

### Decisão

Foi criado:

```text
CapabilityImplementation
    oneof
      function
      script
      application
      service
```

Contratos:

```text
FunctionImplementation
  function_name
  source

ScriptImplementation
  path
  fixed_args

ApplicationImplementation
  executable_path
  fixed_args

ServiceImplementation
  unix_socket
  operation
  timeout_ms
```

A interface de dados é independente do tipo de implementação.

---

## ✅ RESOLVIDO — BLOCKER-07 — Candidate disponível antes de aprovação

### Decisão

O status foi mantido explicitamente, conforme definido:

```text
candidate
validated
approved
active
deprecated
blocked
```

A busca normal exige simultaneamente:

```text
capability.enabled = TRUE
active_version_id IS NOT NULL
capability_version.status = active
```

Além disso:

- há somente uma versão ativa por capability;
- ativação ocorre em transação;
- versões candidate/validated/approved não aparecem em `search_capabilities`.

---

## ✅ RESOLVIDO — BLOCKER-08 — PostgreSQL e filesystem não são transacionais juntos

### Decisão

Não será simulada uma transação distribuída.

Após a validação existem duas operações independentes:

```text
validated plan
     |
     +--> Capability Publisher
     |
     +--> Bash Output
```

Publicação usa:

```text
CapabilityPublishRequest
request_id
idempotency_key
fingerprint
```

O banco possui constraint de fingerprint para concorrência.

`Bash Output` usa gravação atômica no filesystem.

Cada operação é repetível independentemente.

---

# Revisão dos itens HIGH

## ✅ RESOLVIDO — HIGH-01 — Informação obrigatória ausente

Foram adicionados:

```text
NormalizationStatus
MissingInput
NormalizedRequest.status
NormalizedRequest.missing_inputs
```

`MISSING_INFORMATION` interrompe o pipeline antes da pesquisa.

---

## ✅ RESOLVIDO — HIGH-02 — depends_on x result_ref

Semântica definida:

```text
result_ref  = dependência de dados
depends_on  = dependência de controle
```

A aplicação deriva o DAG e detecta ciclos/inconsistências.

---

## ✅ RESOLVIDO — HIGH-03 — Telemetria sem versão

`capability_usage` agora referencia:

```text
capability_version_id
request_id
requested_at
```

Existe unicidade por:

```text
(request_id, capability_version_id)
```

O evento identifica exatamente a definição entregue.

---

## ✅ RESOLVIDO — HIGH-04 — Validação Bash insuficiente

Pipeline obrigatório:

```text
protobuf validation
graph validation
contract validation
version validation
policy validation
deterministic assembly preview
bash -n
ShellCheck
dependency validation
```

O script não é executado.

Se ShellCheck estiver indisponível por erro de ambiente, a validação falha explicitamente.

---

## ✅ RESOLVIDO — HIGH-05 — Confiança de capabilities geradas

Lifecycle:

```text
candidate
validated
approved
active
deprecated
blocked
```

Somente `active` é pesquisável.

Validação técnica não implica ativação automática.

---

## ✅ RESOLVIDO — HIGH-06 — Concorrência gera duplicatas

Publicação usa:

- fingerprint canônica;
- índice único parcial;
- idempotency key;
- transação;
- lock da identidade da capability ao criar nova versão.

Conflito de fingerprint reutiliza a versão existente.

---

## ✅ RESOLVIDO — HIGH-07 — Generation-time tools x runtime capabilities

Conceitos separados:

```text
generation-time tool
    usada pelo LLM durante a geração

runtime capability
    usada pelo arquivo Bash quando executado futuramente
```

Uma tool do gerador não é automaticamente embutida no script.

Essa regra está documentada em [../MCP.md](../MCP.md).

---

## ✅ RESOLVIDO — HIGH-08 — Propriedade dos MCPs

Arquitetura definida:

```text
LLM / llama-server
       |
       v
ai-bash-gen Tool/MCP Orchestrator
       |
       +--> Capability Catalog
       +--> Google Mail
```

O `ai-bash-gen` é autoridade de acesso, validação e auditoria.

---

## ✅ RESOLVIDO — HIGH-09 — Caminhos com ~

Valor semântico e representação shell são separados.

O normalizador preserva:

```text
~/ambiente
```

O materializador pode produzir:

```bash
"$HOME/ambiente"
```

Quoting e expansão segura são responsabilidade exclusiva do `bash-output`.

---

# Revisão dos itens MEDIUM

## ✅ RESOLVIDO — MEDIUM-01 — Crescimento de candidatos

Foi criado `SearchBudget`:

```text
composite_limit
per_task_limit
global_candidate_limit
max_capability_details
```

Candidatos são deduplicados globalmente antes do prompt.

---

## ✅ RESOLVIDO — MEDIUM-02 — get_capability repetido

Existe cache por requisição:

```text
capability_version_id -> CapabilityDefinition
```

A mesma versão é carregada uma única vez por request.

Isso também impede telemetria duplicada na mesma requisição.

---

## ⚠️ ABERTO — MEDIUM-03 — TextProto pode não economizar tokens

Protobuf binário reduz IPC, mas o LLM consome texto.

Não há base suficiente para afirmar que TextProto usa menos tokens que JSON compacto para os modelos selecionados.

### Ação necessária

Depois que os modelos forem fixados, executar benchmark com:

```text
TextProto
JSON compacto
formato compacto alternativo
```

Medir:

- tokens de entrada;
- tokens de saída;
- taxa de parsing válido;
- taxa de aderência ao schema;
- latência.

Até esse benchmark, TextProto permanece escolhido pela consistência de schema, não por uma alegação de economia comprovada.

---

## ✅ RESOLVIDO — MEDIUM-04 — Prompts duplicados

Fontes canônicas:

```text
request-normalizer
  docs/pipeline/01_REQUEST_NORMALIZER.md

bash-generator
  docs/pipeline/04_BASH_GENERATOR.md
```

`AGENTS.md` passa a referenciar os prompts por ID/fonte em vez de duplicar o texto completo.

---

## ✅ RESOLVIDO — MEDIUM-05 — FTS não valida contrato

Busca em duas fases:

```text
candidate retrieval
    intent + FTS
        |
        v
deterministic pruning
    DataContract
    CapabilityInterface
    type/status/policy
        |
        v
LLM candidate view
```

O LLM só recebe candidatos que passaram pela validação estrutural inicial.

---

# Restrição adicional identificada durante a revisão

## ✅ RESOLVIDO — Topologia de streams

A escolha `stdout/stdin` introduz uma restrição natural: existe somente um stdin por processo.

Para a primeira versão:

- pipelines lineares são nativos;
- um stream estruturado por chamada;
- escalares adicionais podem ser argumentos;
- fan-out exige `tee` explícito;
- fan-in exige merge/join explícito;
- o Validator rejeita branching implícito.

Isso mantém a composição previsível sem criar armazenamento temporário oculto.

---

# Ajustes adicionais encontrados na revisão

## ✅ RESOLVIDO — Identidade interna da requisição

`request_id` é gerado pelo `ai-bash-gen` depois que a requisição é aceita.

Ele não é controlado pelo cliente.

Isso evita colisões deliberadas ou acidentais em:

- cache de capability;
- `capability_usage`;
- idempotência de publicação;
- correlação de logs.

`UserRequest` contém somente o conteúdo funcional enviado pelo cliente.

---

## ✅ RESOLVIDO — Mutabilidade de scripts/aplicações externas

Uma versão imutável não pode depender apenas de um path que pode mudar.

Foram adicionados checksums esperados:

```text
ScriptImplementation.expected_sha256
ApplicationImplementation.expected_sha256
ServiceImplementation.client_expected_sha256
```

O Validator confere o conteúdo atual antes de materializar o plano.

Para `SERVICE`, a versão representa o contrato e o cliente controlado. O servidor pode evoluir mantendo a interface versionada.

Na primeira versão, o LLM gera novas capabilities somente do tipo `FUNCTION`. Novos scripts, aplicações e serviços passam por cadastro administrativo.

---

# Ordem atual de implementação

As decisões arquiteturais críticas estão fechadas.

Ordem sugerida para código:

1. gerar código Go a partir de `pipeline.proto`;
2. implementar validação de `DataContract`;
3. implementar DAG/result_ref validation;
4. implementar PostgreSQL `capability` + `capability_version`;
5. implementar lifecycle/activation;
6. implementar `search_capabilities` + deterministic pruning;
7. implementar Tool Orchestrator e generator turn loop;
8. implementar cache e `capability_usage`;
9. implementar Capability Publisher idempotente;
10. implementar assembler Bash determinístico;
11. integrar `bash -n` e ShellCheck;
12. implementar escrita atômica de `BashArtifact`;
13. executar benchmark TextProto x JSON compacto.
