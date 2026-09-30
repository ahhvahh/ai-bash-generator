# MCPs do ai-bash-gen

Este documento define os servidores MCP (Model Context Protocol) previstos para o projeto e as regras de integração com os agentes.

## Princípios

Os MCPs devem ampliar o contexto do agente sem entregar acesso irrestrito ao sistema.

Regras gerais:

- servidores MCP são explicitamente autorizados por configuração;
- cada agente possui uma allowlist de MCPs;
- nenhum MCP deve executar scripts gerados pelo LLM;
- ferramentas destrutivas são proibidas na primeira versão;
- parâmetros e respostas são validados;
- chamadas possuem timeout e limite por requisição;
- informações sensíveis não são registradas integralmente em logs;
- MCPs locais utilizam preferencialmente `stdio`;
- serviços externos são acessados somente pelo MCP que necessita da conexão.

## 1. Capability Catalog MCP

Nome lógico:

```text
capability-catalog
```

O catálogo recebe uma `NormalizedRequest` validada, nunca a frase original do usuário.

A normalização é documentada em [pipeline/02_NORMALIZED_REQUEST.md](pipeline/02_NORMALIZED_REQUEST.md).

O `ai-bash-gen` é o responsável pelo tool loop. O `llama-server` é apenas o motor de inferência.

### Fluxo

```text
NormalizedRequest
        |
        v
search_capabilities
        |
        v
deterministic pruning
        |
        v
LLM receives summarized candidates
        |
        v
GeneratorToolRequest(get_capability)
        |
        v
ai-bash-gen Tool Orchestrator
        |
        v
Capability Catalog
        |
        +--> resolve active immutable version
        +--> append capability_usage(version_id, request_id)
        |
        v
GeneratorToolResponse
```

O mesmo `capability_version_id` é carregado no máximo uma vez por requisição. Requisições repetidas dentro do mesmo pipeline usam cache local.

### `search_capabilities`

A pesquisa possui duas fases:

```text
1. candidate retrieval
   intent + PostgreSQL Full Text Search

2. deterministic pruning
   structured input/output compatibility
   capability type
   lifecycle status
   platform/policy
```

Somente os candidatos restantes são apresentados ao LLM.

A busca tenta:

1. capabilities compostas para a requisição completa;
2. capabilities para cada tarefa individual.

O contrato Protobuf usa `SearchBudget` para limitar o volume total:

```text
composite_limit
per_task_limit
global_candidate_limit
max_capability_details
```

A visão textual entregue ao LLM continua curta:

```text
id
type
description
match_instruction
input_description
output_description
```

Os contratos estruturados ficam disponíveis para o pruner determinístico e não precisam ser repetidos no prompt quando já foram utilizados pela aplicação.

### `get_capability`

O gerador não chama o banco diretamente.

Ele retorna:

```textproto
tool_requests {
  calls {
    call_id: "tool-1"
    get_capability {
      id: "list-directory-details"
    }
  }
}
```

O `ai-bash-gen` executa a chamada e devolve um `GeneratorToolResponse`.

Quando `version` não for informado, o catálogo resolve a versão ativa.

A resposta sempre identifica:

```text
capability id
capability_version_id
version
checksum
```

Isso fixa exatamente qual implementação foi entregue ao gerador.

### Tipos estruturados

A compatibilidade não depende mais de strings como `"table"`.

O contrato utiliza:

```text
DataKind
DataContract
FieldSchema
StreamEncoding
CapabilityInterface
ParameterContract
```

Exemplo conceitual:

```text
stdin_contract:
  kind = TABLE
  fields = name,size,type
  encoding = JSON_LINES

stdout_contract:
  kind = TABLE
  fields = name,size,type
  encoding = JSON_LINES
```

O canal entre capabilities permanece:

```text
producer stdout -> consumer stdin
```

A validação verifica tipo, campos e encoding antes de conectar duas capabilities.

### Tipos de implementação

`CapabilityImplementation` usa `oneof`:

```text
function
script
application
service
```

Contratos iniciais:

```text
function
  function_name
  source

script
  path
  fixed_args

application
  executable_path
  fixed_args

service
  unix_socket
  operation
  timeout_ms
```

Serviços internos devem preferir Unix Domain Socket.

### PostgreSQL

O catálogo utilizará PostgreSQL por Unix Domain Socket local.

```yaml
database:
  driver: postgres
  host: /var/run/postgresql
  database: ai_bash_gen
  user: ai_bash_gen
  sslmode: disable
```

### Identidade lógica

A tabela `capability` guarda somente a identidade pesquisável:

```sql
CREATE TABLE capability (
    id                   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    capability_key       TEXT NOT NULL UNIQUE,
    type                 SMALLINT NOT NULL,
    description          TEXT NOT NULL,
    match_instruction    TEXT NOT NULL,
    input_description    TEXT NOT NULL,
    output_description   TEXT NOT NULL,
    intent               TEXT,
    enabled              BOOLEAN NOT NULL DEFAULT TRUE,
    active_version_id    BIGINT
);
```

### Versões imutáveis

Cada alteração cria uma nova linha em `capability_version`.

```sql
CREATE TABLE capability_version (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    capability_id        INTEGER NOT NULL
                         REFERENCES capability(id)
                         ON DELETE CASCADE,

    version              INTEGER NOT NULL,

    status               SMALLINT NOT NULL DEFAULT 0,

    language             TEXT,

    input_contract       JSONB NOT NULL,
    output_contract      JSONB NOT NULL,
    processing           JSONB,

    implementation       JSONB NOT NULL,
    dependencies         JSONB,

    risk_level           SMALLINT NOT NULL DEFAULT 0,
    complexity_score     SMALLINT NOT NULL DEFAULT 1,

    checksum             TEXT NOT NULL,
    fingerprint          TEXT NOT NULL,

    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (capability_id, version)
);
```

Depois da criação das duas tabelas:

```sql
ALTER TABLE capability
ADD CONSTRAINT fk_capability_active_version
FOREIGN KEY (active_version_id)
REFERENCES capability_version(id);
```

### Status

O status é mantido explicitamente.

```text
0 = candidate
1 = validated
2 = approved
3 = active
4 = deprecated
5 = blocked
```

Uma capability só pode aparecer em `search_capabilities` quando:

```text
capability.enabled = TRUE
AND capability.active_version_id IS NOT NULL
AND capability_version.status = active
```

Exemplo conceitual:

```sql
SELECT
    c.capability_key AS id,
    c.type,
    c.description,
    c.match_instruction,
    c.input_description,
    c.output_description
FROM capability c
JOIN capability_version v
  ON v.id = c.active_version_id
WHERE c.enabled = TRUE
  AND v.status = 3
LIMIT $1;
```

Dessa forma versões `candidate`, `validated` ou `approved` nunca entram na busca normal.

### Pesquisa textual

O índice textual continua sobre a tabela pequena de identidade.

```sql
CREATE INDEX ix_capability_search
ON capability
USING GIN (
    to_tsvector(
        'english',
        coalesce(match_instruction, '') || ' ' ||
        coalesce(input_description, '') || ' ' ||
        coalesce(output_description, '') || ' ' ||
        coalesce(description, '')
    )
)
WHERE enabled = TRUE;
```

Intenção:

```sql
CREATE INDEX ix_capability_intent
ON capability (intent)
WHERE enabled = TRUE;
```

A aplicação deve tentar intenção exata primeiro e executar FTS somente quando necessário ou quando ainda houver orçamento de candidatos.

### Telemetria append-only

O evento aponta para a versão imutável que realmente foi entregue.

```sql
CREATE TABLE capability_usage (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    capability_version_id BIGINT NOT NULL
                          REFERENCES capability_version(id),
    request_id            TEXT NOT NULL,
    requested_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (request_id, capability_version_id)
);
```

Semântica:

```text
uma linha =
esta requisição carregou o conteúdo completo desta versão
```

O cache por requisição impede múltiplas leituras e múltiplos eventos para a mesma versão durante o mesmo processamento.

`search_capabilities` não cria evento.

### Publicação idempotente

Publicar uma capability é uma operação independente da criação do arquivo Bash.

Fluxo:

```text
validated generation
      |
      +--> Capability Publisher
      |      idempotency_key
      |      fingerprint
      |
      +--> Bash Output
```

O publisher recebe `CapabilityPublishRequest`.

A aplicação calcula uma fingerprint canônica da interface e da implementação.

Criar índice/constraint única para impedir publicação concorrente equivalente:

```sql
CREATE UNIQUE INDEX ux_capability_version_fingerprint
ON capability_version (fingerprint)
WHERE status IN (0, 1, 2, 3);
```

Uma colisão de fingerprint deve reutilizar a versão já publicada em vez de criar duplicata.

A chave de idempotência garante que retry da mesma solicitação não publique novamente.

### Separação PostgreSQL x filesystem

Não existe tentativa de criar uma transação distribuída entre banco e filesystem.

As duas operações são independentes e repetíveis:

```text
publish capability
materialize BashArtifact
```

Falha em uma não deve corromper o estado da outra.

O cliente recebe os resultados dessas operações separadamente quando necessário.

## 2. Google Mail MCP

Nome lógico:

```text
google-mail
```

Objetivo: permitir que agentes autorizados pesquisem e leiam e-mails de uma conta Google configurada.

Na primeira versão o MCP será estritamente de leitura.

Ele NÃO poderá:

- enviar e-mails;
- apagar mensagens;
- mover mensagens;
- alterar labels;
- marcar mensagens como lidas;
- modificar a caixa postal.

### Integração Google

Utilizar a Gmail API com OAuth 2.0.

Solicitar o menor escopo possível, inicialmente:

```text
https://www.googleapis.com/auth/gmail.readonly
```

Credenciais e tokens não devem ser armazenados nos arquivos YAML dos agentes.

Diretório sugerido:

```text
/var/lib/ai-bash-gen/secrets/google-mail/
```

Permissões sugeridas:

```text
owner: ai-bash-gen
group: ai-bash-gen
mode: 0700
```

Tokens individuais devem utilizar permissões restritas.

### Ferramentas

#### `search_emails`

Pesquisa mensagens usando critérios controlados.

Entrada conceitual:

```json
{
  "query": "from:empresa@example.com newer_than:30d",
  "limit": 10
}
```

Resposta resumida:

```json
{
  "results": [
    {
      "message_id": "18f...",
      "thread_id": "18f...",
      "from": "empresa@example.com",
      "subject": "Relatório",
      "date": "2026-09-29T10:00:00-03:00",
      "snippet": "Segue o relatório..."
    }
  ]
}
```

A pesquisa não deve retornar o corpo completo de todas as mensagens.

#### `get_email`

Obtém uma mensagem específica.

Entrada:

```json
{
  "message_id": "18f...",
  "include_body": true
}
```

Resposta:

```json
{
  "message_id": "18f...",
  "thread_id": "18f...",
  "from": "empresa@example.com",
  "to": ["usuario@example.com"],
  "cc": [],
  "subject": "Relatório",
  "date": "2026-09-29T10:00:00-03:00",
  "body_text": "Conteúdo...",
  "attachments": [
    {
      "filename": "relatorio.pdf",
      "mime_type": "application/pdf",
      "size": 12345
    }
  ]
}
```

Na primeira versão, anexos são apenas descritos. O download do conteúdo do anexo não é necessário.

#### `get_thread`

Obtém as mensagens de uma conversa quando o contexto da thread for necessário.

Deve possuir limite máximo de mensagens e tamanho total de conteúdo.

### Limites

Configuração sugerida:

```yaml
mcp:
  google_mail:
    enabled: false
    max_search_results: 10
    max_thread_messages: 20
    max_body_bytes: 262144
    timeout: 10s
```

O MCP deve truncar ou rejeitar respostas que excedam os limites configurados.

## 3. Execução dos MCPs

A proposta inicial é implementar os servidores MCP no próprio binário.

Exemplos:

```bash
ai-bash-gen mcp capability-catalog
ai-bash-gen mcp google-mail
```

O `capability-catalog` poderá operar totalmente local e sem rede.

O `google-mail` é uma exceção controlada: precisa de acesso à API do Google. Por isso, seu isolamento deverá ser tratado separadamente do processo de inferência.

Não ampliar o acesso de rede de todo o daemon apenas para permitir Gmail.

A implementação deve preferir separar o processo que acessa Google, com política de rede específica, mantendo o `llama-server` e os demais componentes sem acesso IP.

## 4. Configuração MCP

Arquivo sugerido:

```text
/etc/ai-bash-gen/mcp/servers.yaml
```

Exemplo:

```yaml
version: 1

servers:

  capability-catalog:
    enabled: true
    transport: stdio
    command: /usr/local/bin/ai-bash-gen
    args:
      - mcp
      - capability-catalog
      - --config
      - /etc/ai-bash-gen/config.yaml

  google-mail:
    enabled: false
    transport: stdio
    command: /usr/local/bin/ai-bash-gen
    args:
      - mcp
      - google-mail
      - --config
      - /etc/ai-bash-gen/config.yaml
```

O arquivo deve ser validado antes do uso.

## 5. Controle por agente

Um agente não recebe todos os MCPs automaticamente.

Exemplo:

```yaml
tools:
  mcp:
    allowed:
      - capability-catalog
      - google-mail
```

Se um MCP não estiver nessa lista, o agente não poderá consultá-lo.

## 6. Auditoria

Cada chamada MCP deve gerar telemetria com, no mínimo:

```text
request_id
agent_id
mcp_server
tool
duration_ms
status
error_code
```

Para e-mails, não registrar corpo, assunto completo ou endereço integral em logs operacionais por padrão.

## 7. Evolução prevista

MCPs futuros podem incluir:

- arquivos locais controlados;
- documentação técnica;
- banco de dados corporativo;
- Git;
- inventário de serviços;
- APIs internas.

A inclusão de um novo MCP exige:

1. definição de finalidade;
2. definição das tools;
3. classificação de leitura/escrita;
4. limites;
5. política de segurança;
6. documentação;
7. inclusão explícita na allowlist dos agentes.
