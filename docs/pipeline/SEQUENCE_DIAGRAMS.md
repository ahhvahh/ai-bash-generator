# Diagramas de sequência

Este documento mostra os principais fluxos do pipeline do `ai-bash-gen`.

Os diagramas representam a arquitetura recomendada após a revisão em [../analysis/ARCHITECTURE_REVIEW.md](../analysis/ARCHITECTURE_REVIEW.md).

## Participantes

```text
Client              cliente via Unix Socket
Pipeline            orquestrador ai-bash-gen
Normalizer LLM      request-normalizer
Catalog             Capability Catalog / PostgreSQL
Generator LLM       bash-generator
Tool Orchestrator   controle de get_capability e outros MCPs
Validator           validação determinística
Publisher           publicação idempotente de capabilities
Output              materializador do arquivo Bash
```

## Fluxo 1 — Capability composta existente

Uma capability já resolve toda a solicitação.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as ai-bash-gen Pipeline
    participant N as request-normalizer LLM
    participant C as Capability Catalog
    participant G as bash-generator LLM
    participant T as Tool Orchestrator
    participant V as Validator
    participant O as Bash Output

    Client->>P: UserRequest
    P->>N: UserRequest (TextProto)
    N-->>P: NormalizedRequest
    P->>P: Validate task graph

    P->>C: search_capabilities(request)
    C-->>P: Composite candidates + task candidates

    P->>G: Generation turn + summarized candidates
    G-->>P: GeneratorToolRequests(get_capability)

    P->>T: get_capability(compositeId)
    T->>C: Load active immutable version
    C->>C: Append capability_usage(version_id, request_id)
    C-->>T: CapabilityDefinition
    T-->>P: CapabilityDefinition

    P->>G: GeneratorTurnRequest(tool response)
    G-->>P: Final GenerationPlan

    P->>V: Validate plan + definitions
    V-->>P: Valid

    P->>O: Materialize validated plan
    O-->>P: BashArtifact
    P-->>Client: .sh artifact
```

## Fluxo 2 — Composição de várias capabilities existentes

Nenhuma capability resolve tudo, mas as tarefas individuais possuem implementações reutilizáveis.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant N as Normalizer LLM
    participant C as Catalog
    participant G as Generator LLM
    participant T as Tool Orchestrator
    participant V as Validator
    participant O as Bash Output

    Client->>P: Natural language request
    P->>N: Normalize
    N-->>P: tasks: A -> resultList -> B -> filteredList -> C

    P->>C: Search complete request
    C-->>P: No adequate composite candidate
    P->>C: Search candidates for tasks A/B/C
    C-->>P: Candidate sets

    P->>G: NormalizedRequest + candidate sets

    loop Only for selected candidates
        G-->>P: GeneratorToolRequests(get_capability)
        P->>T: Resolve detail
        T->>C: Load active version
        C->>C: Append usage once per request/version
        C-->>T: CapabilityDefinition
        T-->>P: CapabilityDefinition
        P->>G: GeneratorTurnRequest(tool response)
    end

    G-->>P: GenerationPlan A -> B -> C
    P->>V: Validate data contracts and ABI
    V-->>P: Valid
    P->>O: Assemble functions + bindings
    O-->>P: BashArtifact
    P-->>Client: .sh artifact
```

## Fluxo 3 — Reutilização parcial e geração de função ausente

Algumas tarefas já existem no catálogo, outra precisa ser criada.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant N as Normalizer LLM
    participant C as Catalog
    participant G as Generator LLM
    participant T as Tool Orchestrator
    participant V as Validator
    participant Pub as Capability Publisher
    participant O as Bash Output

    Client->>P: UserRequest
    P->>N: Normalize
    N-->>P: NormalizedRequest with tasks A/B/C

    P->>C: Search capabilities
    C-->>P: A found, B missing, C found

    P->>G: Request + candidates
    G-->>P: GeneratorToolRequests(get_capability A)
    P->>T: Resolve A
    T->>C: Load A version
    C-->>T: A definition
    T-->>P: A definition
    P->>G: GeneratorTurnRequest(A response)

    G-->>P: GeneratorToolRequests(get_capability C)
    P->>T: Resolve C
    T->>C: Load C version
    C-->>T: C definition
    T-->>P: C definition
    P->>G: GeneratorTurnRequest(C response)

    G-->>P: Plan using A + generated B + C

    P->>V: Validate plan and generated B
    V->>C: Dedup lookup/fingerprint
    C-->>V: No equivalent active capability
    V-->>P: Valid; B is publishable candidate

    par Independent post-validation actions
        P->>Pub: Publish B idempotently
        Pub->>C: Insert immutable candidate/version
        C-->>Pub: Published version
    and
        P->>O: Materialize BashArtifact
        O-->>P: BashArtifact
    end

    P-->>Client: .sh artifact
```

## Fluxo 4 — Nenhuma capability encontrada

Todo o comportamento precisa ser criado.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant N as Normalizer LLM
    participant C as Catalog
    participant G as Generator LLM
    participant V as Validator
    participant Pub as Capability Publisher
    participant O as Bash Output

    Client->>P: UserRequest
    P->>N: Normalize
    N-->>P: NormalizedRequest

    P->>C: Search complete + task capabilities
    C-->>P: No suitable candidates

    P->>G: NormalizedRequest + empty candidate sets
    G-->>P: Generated reusable capabilities + call plan

    P->>V: Validate generated functions
    V->>C: Dedup/fingerprint check
    C-->>V: Not found
    V-->>P: Valid

    par
        P->>Pub: Publish generated capabilities
        Pub->>C: Transactional insert
        C-->>Pub: Version IDs
    and
        P->>O: Assemble BashArtifact
        O-->>P: Artifact
    end

    P-->>Client: .sh artifact
```

## Fluxo 5 — Informação obrigatória ausente

O pipeline deve parar cedo.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant N as Normalizer LLM

    Client->>P: "copie os arquivos para o destino"
    P->>N: UserRequest
    N-->>P: NormalizedRequest(status=MISSING_INFORMATION)

    P->>P: Validate normalization

    alt Missing required input
        P-->>Client: MissingInformation(destination)
    else Complete
        P->>P: Continue to capability search
    end
```

A pesquisa no catálogo e o gerador não devem ser acionados quando faltar entrada essencial.

## Fluxo 6 — Falha de validação e uma correção

O resultado do LLM é inválido, mas a política permite uma única correção.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant G as Generator LLM
    participant V as Validator
    participant O as Bash Output

    P->>G: GeneratorTurnRequest
    G-->>P: GenerationPlan
    P->>V: Validate
    V-->>P: Invalid + structured issues

    alt Correction attempt available
        P->>G: Previous plan + ValidationIssue list
        G-->>P: Corrected GenerationPlan
        P->>V: Validate corrected plan
        alt Valid
            V-->>P: Valid
            P->>O: Materialize
            O-->>P: BashArtifact
            P-->>Client: .sh artifact
        else Still invalid
            V-->>P: Invalid
            P-->>Client: Generation failed + issues
        end
    else No retry
        P-->>Client: Generation failed + issues
    end
```

## Fluxo 7 — Ferramenta externa necessária durante a geração

Exemplo: o usuário pede conteúdo de e-mail atual para ser incorporado à geração.

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant P as Pipeline
    participant N as Normalizer LLM
    participant G as Generator LLM
    participant T as Tool Orchestrator
    participant Mail as Google Mail MCP
    participant V as Validator
    participant O as Bash Output

    Client->>P: Request requiring current email data
    P->>N: Normalize
    N-->>P: NormalizedRequest

    P->>G: Request + permitted generation-time tools
    G-->>P: GeneratorToolRequest(generation_time_mcp: search_emails)

    P->>T: Authorize tool request
    T->>Mail: search_emails
    Mail-->>T: Summaries
    T-->>P: Sanitized results
    P->>G: GeneratorTurnRequest(McpToolResult)

    G-->>P: GeneratorToolRequest(generation_time_mcp: get_email)
    P->>T: Authorize
    T->>Mail: get_email
    Mail-->>T: Content
    T-->>P: Sanitized content
    P->>G: GeneratorTurnRequest(McpToolResult)

    G-->>P: Final generation plan
    P->>V: Validate
    V-->>P: Valid
    P->>O: Materialize
    O-->>P: BashArtifact
    P-->>Client: .sh artifact
```

Este fluxo é diferente de um script que precisará consultar Gmail futuramente. Nesse segundo caso, Gmail precisa existir como **runtime capability** e não apenas como ferramenta do gerador.

## Fluxo 8 — Publicação concorrente de capability equivalente

Duas requisições tentam criar a mesma funcionalidade.

```mermaid
sequenceDiagram
    autonumber
    participant P1 as Pipeline Request A
    participant P2 as Pipeline Request B
    participant Pub as Capability Publisher
    participant DB as PostgreSQL

    P1->>Pub: Publish generated capability + fingerprint X
    P2->>Pub: Publish generated capability + fingerprint X

    Pub->>DB: INSERT fingerprint X (unique)
    DB-->>Pub: Success / version_id=10

    Pub->>DB: INSERT fingerprint X (unique)
    DB-->>Pub: Unique conflict

    Pub->>DB: SELECT active/candidate version WHERE fingerprint=X
    DB-->>Pub: version_id=10

    Pub-->>P1: version_id=10
    Pub-->>P2: reuse version_id=10
```

A deduplicação precisa ser garantida pelo banco ou lock transacional; uma busca anterior ao insert não é suficiente.

## Fluxo 9 — Runtime do arquivo Bash

A geração termina quando o arquivo é criado. Sua execução é outro fluxo.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Bash as Generated .sh
    participant F1 as Capability Function A
    participant F2 as Capability Function B

    User->>Bash: Execute script explicitly
    Bash->>F1: Call with literal arguments
    F1-->>Bash: resultList using canonical ABI
    Bash->>F2: Pass resultList using canonical ABI
    F2-->>Bash: finalResult
    Bash-->>User: Requested output
```

O ABI deste fluxo está definido como `stdout -> stdin`. O tipo e a codificação do stream são validados por `DataContract`.

## Regra de topologia de streams

O ABI Unix resolve o transporte, mas cada processo possui um único `stdin`.

Na primeira versão, um stream linear é suportado diretamente:

```text
A | B | C
```

Fan-out ou fan-in não são montados implicitamente:

```text
      +--> B
A ----+
      +--> C

B ----+
      +--> D
C ----+
```

Esses casos exigem uma capability explícita de `tee`, merge/join ou materialização intermediária. O Validator rejeita um plano que tente criar essa topologia sem uma operação explícita.
