# Revisão de Arquitetura V2

Esta é a segunda revisão de arquitetura do ai-bash-gen.

A V1 permanece disponível em [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md) e registra as decisões anteriores.

A V2 parte do estado atual do projeto, no qual:

- o pipeline já possui contratos Protobuf;
- stdout -> stdin é o ABI de composição;
- o gerador produz GenerationPlan;
- existe tool loop formal;
- capabilities possuem versões imutáveis;
- a busca utiliza PostgreSQL + pruning determinístico;
- publicação e criação do Bash são operações independentes;
- somente FUNCTION pode ser criada diretamente pelo LLM na primeira versão.

Contrato atual: [pipeline.proto](../../proto/ai_bash_gen/v1/pipeline.proto)

Pipeline: [pipeline/README.md](../pipeline/README.md)

> Esta V2 é uma análise. Os itens abaixo ainda não alteram automaticamente os contratos do projeto.

---

# 1. Resumo executivo

A arquitetura evoluiu, mas a revisão V2 encontrou novos problemas que aparecem na implementação real.

~~~text
BLOCKER   9 abertos
HIGH      12 abertos
MEDIUM     6 abertos
~~~

Os principais riscos são:

1. uma capability pode mudar de versão entre search_capabilities e get_capability;
2. o normalizador está escolhendo encoding de stream, embora devesse ser independente da implementação;
3. ainda não existe um contrato que diga como argumentos nomeados viram argumentos reais de uma função/aplicação;
4. código de function pode colidir com outras functions ou executar código no momento em que é incorporado;
5. side effects não estão estruturados, impedindo validação de operações destrutivas;
6. o tool loop pode ultrapassar rapidamente o contexto de 4096 tokens;
7. dois agentes com modelos diferentes não possuem estratégia de lifecycle em um único llama-server;
8. o protocolo externo do daemon ainda não possui envelope de request/response/error/cancel;
9. não está definido se o .sh é portátil ou vinculado ao servidor onde foi gerado.

---

# 2. BLOCKERS V2

## 🔴 V2-BLOCKER-01 — Race entre search e get_capability

### Problema

Hoje CapabilityCandidate identifica principalmente:

~~~text
id
type
description
interface
~~~

Depois:

~~~text
search_capabilities
        |
        | candidate id = X
        v
...
        |
        v
get_capability(id = X)
~~~

Se uma nova versão for ativada entre as duas operações:

~~~text
search -> version 4
activation -> version 5
get -> version 5
~~~

o LLM recebe detalhes diferentes daqueles usados pelo pruning.

### Impacto

- TOCTOU entre pesquisa e detalhe;
- interface pode mudar;
- descrição pode mudar;
- plano pode usar comportamento diferente do candidato avaliado;
- telemetria registra uma versão que não foi a versão pesquisada.

### Proposta

search_capabilities deve fixar a versão:

~~~text
CapabilityCandidate
  capability_id
  capability_version_id
  version
~~~

get_capability deve receber preferencialmente capability_version_id e nunca resolver novamente a versão ativa para um candidato já retornado.

### Sequência recomendada

~~~mermaid
sequenceDiagram
    autonumber
    participant P as Pipeline
    participant C as Catalog
    participant G as Generator

    P->>C: search_capabilities
    C->>C: Resolve active version = 42
    C-->>P: candidate(id=X, version_id=42)

    Note over C: Version 43 may become active now

    P->>G: candidate(version_id=42)
    G-->>P: get_capability(version_id=42)
    P->>C: Load immutable version 42
    C-->>P: CapabilityDefinition(version_id=42)
    P->>G: Tool response
~~~

---

## 🔴 V2-BLOCKER-02 — Metadados pesquisáveis e versão podem divergir

### Problema

A tabela lógica capability contém descrição, match instruction, input/output descriptions e type, enquanto a implementação e os contratos pertencem à versão.

Isso cria duas fontes de estado:

~~~text
capability
    semântica pesquisável

capability_version
    comportamento versionado
~~~

Se uma versão alterar a interface ou o significado da capability, a pesquisa pode continuar descrevendo o comportamento anterior.

### Proposta

Manter em capability apenas identidade estável:

~~~text
id
capability_key
enabled
active_version_id
~~~

Mover para capability_version:

~~~text
type
description
match_instruction
input_description
output_description
interface
implementation
risk
checksum
fingerprint
~~~

Para performance, usar uma projeção/index da versão ativa em vez de duplicar estado manualmente.

---

## 🔴 V2-BLOCKER-03 — Logical type está misturado com transport encoding

### Problema

O request-normalizer deve ser independente da implementação.

Porém hoje ele pode produzir:

~~~text
DataContract
  kind = TABLE
  encoding = JSON_LINES
~~~

O usuário pediu uma tabela; ele não pediu JSON Lines.

Escolher JSON_LINES nessa etapa é uma decisão de transporte.

### Risco

Uma tarefa semanticamente compatível pode ser rejeitada porque:

~~~text
NormalizedRequest: TABLE / JSON_LINES
Capability:        TABLE / TSV
~~~

mesmo que ambas produzam os mesmos campos.

### Proposta

Separar:

~~~text
LogicalDataContract
    tipo semântico
    campos
    nullable

StreamContract
    encoding
    framing
~~~

O normalizador gera somente LogicalDataContract.

Capabilities definem:

~~~text
logical contract
+
stream contract
~~~

O planner pode conectar diretamente encodings iguais, procurar uma capability converter ou rejeitar a composição.

---

## 🔴 V2-BLOCKER-04 — Falta contrato de binding/invocação

### Problema

Temos ParameterContract e ArgumentBinding, mas o assembler não sabe transformar:

~~~text
name = "path"
value = "/tmp"
~~~

em uma chamada real.

Exemplos:

~~~bash
my_function "/tmp"
my_app --path "/tmp"
my_app -p "/tmp"
my_app "/tmp" --recursive
my_app --path=/tmp
~~~

### Impacto

O bash-output ainda não consegue ser realmente determinístico.

### Proposta

Adicionar InvocationParameter:

~~~text
name
binding_type
position
flag
repeatable
separator
required
~~~

Tipos iniciais:

~~~text
POSITIONAL
FLAG_VALUE
FLAG_BOOLEAN
ENVIRONMENT
STDIN
~~~

Functions geradas podem adotar:

~~~text
argument order = CapabilityInterface.arguments order
~~~

Scripts e applications precisam de binding explícito.

---

## 🔴 V2-BLOCKER-05 — FunctionImplementation não possui isolamento de símbolos

### Problema

O arquivo final pode incorporar várias capabilities:

~~~bash
function parse() { ... }
function helper() { ... }

function convert() { ... }
function helper() { ... }
~~~

A segunda definição sobrescreve a primeira.

Além disso, source pode conter código top-level:

~~~bash
rm ...
export ...
cd ...
function foo() { ... }
~~~

Esse código executaria assim que fosse incorporado ao script.

### Proposta

Para FunctionImplementation:

- permitir somente definições de função;
- proibir comandos top-level;
- identificar todos os símbolos definidos;
- namespace obrigatório por capability/version;
- renomear ou rejeitar colisões;
- evitar variáveis globais;
- usar subshell quando isolamento for necessário.

Exemplo:

~~~text
cap_42_list_files
cap_42__helper_parse
~~~

O Validator precisa de análise estrutural/AST Bash; regex isolada não é suficiente.

---

## 🔴 V2-BLOCKER-06 — Side effects não fazem parte do contrato

### Problema

O sistema conhece input, output e risk_level, mas não descreve o que a capability altera.

Exemplos:

~~~text
read filesystem
write file
delete file
change permission
restart service
network request
send email
modify database
~~~

Uma capability pode retornar PATH e ao mesmo tempo apagar arquivos.

### Proposta

Criar CapabilityEffects:

~~~text
filesystem:
  read
  create
  modify
  delete

process:
  execute
  signal

network:
  connect

service:
  start
  stop
  restart

privilege:
  requires_root
~~~

NormalizedTask também deve representar os efeitos esperados pelo pedido do usuário.

Validação:

~~~text
requested effects
      vs
capability effects
      vs
policy
~~~

Sem isso, risk_level é informativo, mas insuficiente para autorização.

---

## 🔴 V2-BLOCKER-07 — Estratégia de contexto do generator não está definida

### Problema

Cada turno pode conter:

~~~text
NormalizedRequest
SearchCapabilitiesResponse
tool responses
CapabilityDefinition source
MCP results
prompt
GenerationPlan
~~~

Se toda informação anterior for reenviada, o contexto pode exceder rapidamente o limite do modelo.

### Risco

- truncamento;
- perda de instruções;
- respostas inválidas;
- latência elevada;
- consumo excessivo de CPU.

### Proposta

Criar GeneratorSession no Pipeline Manager:

~~~text
request
candidate index
resolved capability cache
tool results
token budget
turn number
~~~

Definir orçamento:

~~~text
max_context_tokens
reserved_output_tokens
max_tool_result_tokens
max_capability_source_tokens
max_turns
~~~

Antes de chamar o modelo:

~~~text
estimate tokens
      |
      +--> within budget -> infer
      |
      +--> over budget -> compact/reject
~~~

---

## 🔴 V2-BLOCKER-08 — Lifecycle de modelos incompatível com models_max=1

### Problema

A arquitetura prevê:

~~~text
request-normalizer -> modelo A
bash-generator     -> modelo B
~~~

e hardware limitado com apenas um modelo carregado.

Não está definido como um único llama-server alternará modelos.

### Opções

1. um único modelo atende os dois agentes;
2. parar/reiniciar llama-server entre etapas;
3. supervisor mantém workers separados;
4. modelo único na V1 e múltiplos depois.

### Proposta inicial

Para V1:

~~~text
one loaded model
multiple prompts/agents
~~~

Se modelos diferentes forem obrigatórios, documentar unload/reload, timeout, fila, health check, falha de carregamento e rollback.

---

## 🔴 V2-BLOCKER-09 — Protocolo externo do daemon incompleto

### Problema

O projeto define Unix Domain Socket + frame + Protobuf, mas pipeline.proto contém contratos internos, não um protocolo completo de cliente.

Faltam:

~~~text
request envelope
response envelope
request correlation
error envelope
protocol version
cancel request
artifact delivery
max message size semantics
~~~

### Proposta

Criar:

~~~text
proto/ai_bash_gen/v1/api.proto
~~~

com:

~~~text
ClientRequest
ClientResponse
RequestError
CancelRequest
GenerateBashRequest
GenerateBashResponse
HealthRequest
HealthResponse
~~~

O servidor gera request_id.

Definir explicitamente:

~~~text
max frame size
timeouts
cancellation
one request per connection ou multiplexing
EOF behavior
error codes
version negotiation
~~~

---

# 3. Problemas HIGH V2

## 🟠 V2-HIGH-01 — Literal continua sendo string

TaskInput.literal e ArgumentBinding.literal perdem tipagem para INTEGER, DECIMAL, BOOLEAN, PATH e LIST.

### Proposta

Criar TypedValue com oneof:

~~~text
string_value
int64_value
double_value
bool_value
path_value
list_value
~~~

---

## 🟠 V2-HIGH-02 — Semântica de scalar result_ref não está definida

Um resultado pode alimentar argumento escalar:

~~~text
producer stdout -> capture -> argument of consumer
~~~

Faltam regras para tamanho, newline, múltiplas linhas, NUL e stdout vazio.

### Proposta

ScalarCapturePolicy inicial:

~~~text
UTF-8
max 64 KiB
trim exactly one trailing newline
reject NUL
reject multiple records when scalar
~~~

---

## 🟠 V2-HIGH-03 — Exit code 1 nem sempre significa falha lógica

Vários comandos Unix possuem códigos de retorno semânticos.

Exemplo:

~~~text
grep
0 = match
1 = no match
2 = error
~~~

### Proposta

Adicionar ExitCodeContract por implementation.

---

## 🟠 V2-HIGH-04 — BashArtifact não declara dependências

Hoje o artifact não informa executáveis, versões, serviços, paths externos, sockets ou runtime capabilities necessários.

### Proposta

Adicionar BashArtifactRequirements.

---

## 🟠 V2-HIGH-05 — Portabilidade do .sh não está definida

Dois modos:

~~~text
SELF_CONTAINED
HOST_BOUND
~~~

Uma function incorporada pode ser portátil; uma application ou service local não.

### Proposta

Adicionar ExecutionTarget e ArtifactPortability.

---

## 🟠 V2-HIGH-06 — Checksum externo só é verificado na geração

Um executável pode mudar entre geração e execução futura.

### Proposta

Para artifact HOST_BOUND:

- guarda de checksum no próprio script; ou
- runtime launcher do ai-bash-gen que valida a versão antes de executar.

---

## 🟠 V2-HIGH-07 — Approval/activation não possui ator e operação

O lifecycle existe, mas falta definir quem aprova e quem ativa.

### Proposta

Operações administrativas:

~~~text
capability approve
capability activate
capability block
capability deprecate
~~~

Auditar actor, timestamp, reason, previous_version e new_version.

---

## 🟠 V2-HIGH-08 — Validação estática não prova comportamento

bash -n + ShellCheck não provam que a função ordena, filtra ou retorna os campos declarados.

### Proposta

Adicionar CapabilityTestCase.

Fluxo possível:

~~~text
candidate
static validation
sandbox tests, quando habilitado
validated
approval
~~~

Se execução de código gerado permanecer proibida, promoção para active deve exigir aprovação humana ou teste externo confiável.

---

## 🟠 V2-HIGH-09 — Prompt injection via MCP/tool output

Conteúdo de Gmail, descrições, código-fonte ou serviços pode conter instruções maliciosas para o LLM.

### Proposta

- tratar tool output como dado não confiável;
- separar instrução e conteúdo;
- limitar campos;
- nunca permitir que tool content altere allowlist;
- validar ações fora do LLM;
- aplicar policy depois da geração.

---

## 🟠 V2-HIGH-10 — Cancellation, timeout e backpressure não estão fechados

Em 2 cores, inferência abandonada pode bloquear toda a fila.

### Proposta

Propagar context.Context para:

~~~text
llama
PostgreSQL
MCP
filesystem
publisher
~~~

Definir max queue length, queue timeout, inference timeout, tool timeout e request timeout.

---

## 🟠 V2-HIGH-11 — Reload de configuração durante request

Sem snapshot:

~~~text
turn 1 -> config A
SIGHUP
turn 2 -> config B
~~~

### Proposta

Capturar no início:

~~~text
AgentConfigSnapshot
ModelProfileSnapshot
PolicySnapshot
~~~

O request inteiro usa o mesmo snapshot.

---

## 🟠 V2-HIGH-12 — Migrações PostgreSQL não estão definidas

Faltam criação inicial, upgrade, rollback e compatibilidade entre binário e schema.

### Proposta

Criar schema_migrations e migrations versionadas.

Startup:

~~~text
read schema version
      |
      +--> compatible -> start
      |
      +--> migration required -> explicit migrate
      |
      +--> incompatible -> fail closed
~~~

---

# 4. Problemas MEDIUM V2

## 🟡 V2-MEDIUM-01 — TextProto continua sem benchmark

Permanece da V1.

Medir com tokenizer real do modelo.

---

## 🟡 V2-MEDIUM-02 — Ranking da busca não está especificado

Definir score e tie-break determinísticos:

~~~text
exact intent
contract specificity
FTS rank
capability version
capability id
~~~

---

## 🟡 V2-MEDIUM-03 — Fingerprint precisa de canonicalização formal

A fingerprint não pode variar por ordem de JSON, whitespace, comentário ou nome temporário.

Definir quais campos entram e como são canonicalizados.

---

## 🟡 V2-MEDIUM-04 — risk_level deve ser enum/constraint

Criar enum Protobuf e CHECK no PostgreSQL.

---

## 🟡 V2-MEDIUM-05 — Filename/path de saída precisa de regra explícita

requested_filename deve ser basename controlado.

Sugestão:

~~~text
[a-zA-Z0-9._-]
no ".."
no "/"
max length
~~~

O diretório de saída pertence à configuração do serviço.

---

## 🟡 V2-MEDIUM-06 — Protocolo e schema precisam de versão funcional

Além da compatibilidade binária do Protobuf, registrar quando necessário:

~~~text
protocol_version
pipeline_contract_version
capability_contract_version
~~~

---

# 5. Diagramas de sequência

## Fluxo A — Capability composta existente

~~~mermaid
sequenceDiagram
    autonumber
    actor Client
    participant API as UDS API
    participant P as Pipeline
    participant N as Normalizer LLM
    participant C as Catalog
    participant G as Generator LLM
    participant T as Tool Orchestrator
    participant V as Validator
    participant O as Bash Output

    Client->>API: GenerateBashRequest
    API->>P: UserRequest + internal request_id
    P->>N: Normalize
    N-->>P: NormalizedRequest(READY)
    P->>P: Validate logical task graph
    P->>C: Search active capabilities
    C-->>P: Candidate(version_id=42)
    P->>P: Deterministic pruning
    P->>G: GeneratorTurnRequest(candidate 42)
    G-->>P: ToolRequest(get version 42)
    P->>T: Authorize request
    T->>C: get capability_version_id=42
    C-->>T: immutable CapabilityDefinition
    T-->>P: ToolResponse
    P->>G: Next generator turn
    G-->>P: GenerationPlan
    P->>V: Validate
    V-->>P: ValidationResult(valid)
    P->>O: Materialize
    O-->>P: BashArtifact
    P-->>API: GenerateBashResponse
    API-->>Client: artifact + requirements
~~~

---

## Fluxo B — Composição de várias capabilities

~~~mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant C as Catalog
    participant G as Generator
    participant T as Tool Orchestrator
    participant V as Validator
    participant O as Bash Output

    Client->>P: Request
    P->>C: Search full request + tasks
    C-->>P: A(v10), B(v21), C(v7)
    P->>G: Pruned candidates

    loop Selected immutable versions only
        G-->>P: get_capability(version_id)
        P->>T: Resolve
        T->>C: Read immutable version
        C-->>T: Definition
        T-->>P: Definition
        P->>G: Tool response
    end

    G-->>P: Plan A -> resultList -> B -> filteredList -> C
    P->>V: Validate contracts + invocation bindings
    V-->>P: Valid
    P->>O: Assemble A | B | C
    O-->>P: BashArtifact
    P-->>Client: Artifact
~~~

---

## Fluxo C — Nova function gerada

~~~mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant C as Catalog
    participant G as Generator
    participant V as Validator
    participant Pub as Publisher
    participant O as Bash Output

    Client->>P: Request
    P->>C: Search
    C-->>P: No adequate candidate
    P->>G: GeneratorTurnRequest
    G-->>P: GenerationPlan + GeneratedCapability(FUNCTION)
    P->>V: Static validation
    V->>C: Check fingerprint
    C-->>V: No equivalent version
    V-->>P: Valid candidate

    par Independent operations
        P->>Pub: Publish as candidate
        Pub->>C: Idempotent insert
        C-->>Pub: candidate version_id
    and
        P->>O: Embed validated function
        O-->>P: BashArtifact
    end

    P-->>Client: Artifact
~~~

A function publicada não se torna automaticamente active.

---

## Fluxo D — Aprovação e ativação

~~~mermaid
sequenceDiagram
    autonumber
    actor Admin
    participant CLI as ai-bash-gen CLI
    participant C as Catalog

    Admin->>CLI: capability approve version 55
    CLI->>C: Validate state transition
    C->>C: candidate/validated -> approved
    C-->>CLI: approved

    Admin->>CLI: capability activate version 55
    CLI->>C: Begin transaction + lock capability
    C->>C: deactivate previous active
    C->>C: set version 55 active
    C->>C: update active_version_id
    C->>C: commit
    C-->>CLI: active
~~~

---

## Fluxo E — Informação obrigatória ausente

~~~mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant N as Normalizer

    Client->>P: "copie os arquivos"
    P->>N: UserRequest
    N-->>P: NormalizedRequest(MISSING_INFORMATION)
    P->>P: Validate MissingInput
    P-->>Client: Missing destination

    Note over P: Catalog and Generator are not called
~~~

---

## Fluxo F — Tool externa durante geração

~~~mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant G as Generator
    participant T as Tool Orchestrator
    participant M as Google Mail MCP

    Client->>P: Request requiring current email content
    P->>G: GeneratorTurnRequest
    G-->>P: McpToolRequest(search_emails)
    P->>T: Authorize + validate schema
    T->>M: search_emails
    M-->>T: Untrusted data
    T-->>P: Sanitized and limited result
    P->>G: GeneratorTurnRequest(tool result)
    G-->>P: GenerationPlan
~~~

---

## Fluxo G — Falha de validação com uma correção

~~~mermaid
sequenceDiagram
    autonumber
    participant P as Pipeline
    participant G as Generator
    participant V as Validator
    participant O as Bash Output

    P->>G: Generator turn
    G-->>P: GenerationPlan
    P->>V: Validate
    V-->>P: Invalid + issues

    alt retry available
        P->>G: Correction turn + issues
        G-->>P: Corrected plan
        P->>V: Validate again
        alt valid
            V-->>P: Valid
            P->>O: Materialize
            O-->>P: Artifact
        else invalid
            V-->>P: Invalid
            P->>P: Fail request
        end
    else no retry
        P->>P: Fail request
    end
~~~

---

## Fluxo H — Cancelamento/timeout

~~~mermaid
sequenceDiagram
    autonumber
    actor Client
    participant API as UDS API
    participant P as Pipeline
    participant L as llama-server
    participant T as Tool Orchestrator

    Client->>API: Generate request
    API->>P: context + deadline
    P->>L: Inference

    Client-->>API: Disconnect or CancelRequest
    API->>P: cancel context

    par cancellation propagation
        P-->>L: cancel inference
    and
        P-->>T: cancel pending tools
    end

    P->>P: release queue slot and resources
~~~

---

## Fluxo I — Modelo único para dois agentes

Fluxo recomendado para V1:

~~~mermaid
sequenceDiagram
    autonumber
    participant P as Pipeline
    participant M as Model Manager
    participant L as llama-server

    P->>M: request-normalizer inference
    M->>L: same GGUF + normalizer prompt
    L-->>M: NormalizedRequest
    M-->>P: result

    P->>M: bash-generator inference
    M->>L: same GGUF + generator prompt
    L-->>M: GeneratorTurnResult
    M-->>P: result
~~~

---

## Fluxo J — Execução futura do artifact

~~~mermaid
sequenceDiagram
    autonumber
    actor User
    participant B as BashArtifact
    participant A as External Application
    participant S as Runtime Service

    User->>B: Execute

    alt SELF_CONTAINED
        B->>B: Execute embedded functions
        B-->>User: Output
    else HOST_BOUND application
        B->>B: Validate runtime guard
        B->>A: Invoke pinned application contract
        A-->>B: stdout
        B-->>User: Output
    else HOST_BOUND service
        B->>S: Invoke versioned service contract
        S-->>B: response
        B-->>User: Output
    end
~~~

---

# 6. Dependências entre problemas

~~~text
V2-BLOCKER-01 version pin
        |
        +--> V2-BLOCKER-02 searchable version metadata

V2-BLOCKER-03 logical vs stream
        |
        +--> V2-BLOCKER-04 invocation
        +--> scalar capture
        +--> exit code semantics

V2-BLOCKER-05 function isolation
        |
        +--> functional tests
        +--> validation AST

V2-BLOCKER-06 effects
        |
        +--> policy
        +--> approval
        +--> risk level

V2-BLOCKER-07 token/session budget
        |
        +--> V2-BLOCKER-08 model lifecycle

V2-BLOCKER-09 external API
        |
        +--> cancellation
        +--> error model
        +--> protocol version
~~~

---

# 7. Ordem recomendada de resolução V2

Antes de iniciar o daemon completo:

1. fixar capability_version_id em CapabilityCandidate;
2. mover semântica pesquisável variável para capability_version;
3. separar contrato lógico de encoding de stream;
4. definir InvocationParameter e regras de binding;
5. definir isolamento/namespacing de FunctionImplementation;
6. criar CapabilityEffects;
7. definir API externa em api.proto;
8. definir GeneratorSession e orçamento de contexto;
9. decidir modelo único para V1 ou lifecycle explícito de múltiplos modelos;
10. definir TypedValue e scalar capture;
11. criar manifest de dependências/portabilidade do BashArtifact;
12. definir workflow administrativo approve/activate;
13. criar migrations PostgreSQL;
14. implementar cancellation/backpressure;
15. definir testes de capability;
16. executar benchmark TextProto x JSON.

---

# 8. Critério de início de implementação

A implementação do esqueleto Go pode começar antes de todos os itens HIGH/MEDIUM estarem fechados.

Porém todos os itens V2-BLOCKER devem estar resolvidos no contrato antes do assembler real e do catálogo entrarem em produção.

Sem essas decisões, existe risco de alterações simultâneas em:

~~~text
Protobuf
PostgreSQL
Generator prompt
Validator
Bash assembler
Tool loop
Client protocol
Model manager
~~~
