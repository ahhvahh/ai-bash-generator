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

O catálogo recebe uma `NormalizedRequest`, nunca a frase original do usuário.

A normalização é documentada separadamente em [NORMALIZED_REQUEST.md](NORMALIZED_REQUEST.md).

O MCP é consultivo: ele pesquisa e entrega definições de capacidades, mas não executa scripts ou aplicações.

### Fluxo

```text
NormalizedRequest
        |
        v
search_capabilities
        |
        v
até N candidatos resumidos
        |
        v
LLM compara:
- objetivo
- entrada
- saída
        |
        v
get_capability(id)
        |
        +--> append capability_usage
        |
        v
definição completa
```

### `search_capabilities`

A pesquisa deve retornar somente informações suficientes para o LLM escolher o candidato mais adequado.

Entrada conceitual:

```json
{
  "intent": "list_directory_items",
  "instruction": "List directory items with name, size and permissions ordered by size descending.",
  "input_description": "Directory path, selected fields, sort field and sort direction.",
  "output_description": "Table containing name, size and permissions.",
  "limit": 5
}
```

Resposta:

```json
{
  "results": [
    {
      "id": "list-directory-details",
      "type": "function",
      "description": "List directory items with selectable metadata and sorting.",
      "match_instruction": "List directory items with metadata and optional sorting.",
      "input_description": "Directory path, selected fields, sort field and sort direction.",
      "output_description": "Table containing one row per item with the selected fields."
    }
  ]
}
```

Cada resultado deve conter somente:

- `id`;
- `type`;
- `description`;
- `match_instruction`;
- `input_description`;
- `output_description`.

Não retornar nessa etapa:

- código;
- endereço;
- dependências;
- contratos detalhados;
- versão;
- complexidade;
- telemetria;
- timestamps.

A ideia é manter o payload pequeno, mas ainda permitir que o LLM diferencie capacidades parecidas pela entrada aceita e pela saída produzida.

### `get_capability`

Depois de escolher um candidato, o agente solicita sua definição completa:

```json
{
  "id": "list-directory-details"
}
```

Resposta conceitual:

```json
{
  "id": "list-directory-details",
  "type": "function",
  "description": "List directory items with selectable metadata and sorting.",
  "inputs": [
    {
      "name": "path",
      "type": "path",
      "required": true
    },
    {
      "name": "fields",
      "type": "list",
      "allowed": ["name", "size", "permissions"]
    },
    {
      "name": "sort_by",
      "type": "string",
      "allowed": ["name", "size"]
    },
    {
      "name": "sort_order",
      "type": "string",
      "allowed": ["asc", "desc"]
    }
  ],
  "outputs": {
    "type": "table",
    "available_fields": ["name", "size", "permissions"]
  },
  "source": "list_directory_details() { ... }"
}
```

A chamada de `get_capability` representa interesse concreto do agente naquela capacidade e deve gerar um registro append-only em `capability_usage`.

### Tipos

Valores iniciais:

```text
1 = function
2 = script
3 = application
4 = service
```

### PostgreSQL

O catálogo utilizará PostgreSQL, preferencialmente por Unix Domain Socket local.

```yaml
database:
  driver: postgres
  host: /var/run/postgresql
  database: ai_bash_gen
  user: ai_bash_gen
  sslmode: disable
```

### Tabela de pesquisa

A tabela usada por `search_capabilities` deve permanecer pequena:

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
    enabled              BOOLEAN NOT NULL DEFAULT TRUE
);
```

Consulta de retorno:

```sql
SELECT
    capability_key AS id,
    type,
    description,
    match_instruction,
    input_description,
    output_description
FROM capability
WHERE enabled = TRUE
LIMIT $1;
```

### Pesquisa textual

Como o texto interno é normalizado para inglês, usar Full Text Search do PostgreSQL.

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
);
```

Criar também índice parcial para intenção:

```sql
CREATE INDEX ix_capability_intent
ON capability (intent)
WHERE enabled = TRUE;
```

Prioridade de busca:

1. `intent` exato;
2. `match_instruction`;
3. `input_description`;
4. `output_description`;
5. `description`.

### Tabela de detalhes

Dados grandes ou pouco acessados ficam separados:

```sql
CREATE TABLE capability_detail (
    capability_id       INTEGER PRIMARY KEY
                        REFERENCES capability(id)
                        ON DELETE CASCADE,

    version             SMALLINT NOT NULL DEFAULT 1,
    language            TEXT,

    input_contract      JSONB,
    processing          JSONB,
    output_contract     JSONB,

    source_code         TEXT,
    address             TEXT,
    invocation          JSONB,
    dependencies        JSONB,

    risk_level          SMALLINT NOT NULL DEFAULT 0,
    complexity_score    SMALLINT NOT NULL DEFAULT 1,

    origin              SMALLINT NOT NULL DEFAULT 0,
    status              SMALLINT NOT NULL DEFAULT 0,

    checksum            TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Mapeamentos sugeridos:

```text
risk_level:
0 = read_only
1 = low
2 = medium
3 = high

origin:
0 = manual
1 = generated

status:
0 = candidate
1 = validated
2 = active
3 = deprecated
```

### Registro append-only

Não manter contador atualizado na linha da capability.

Registrar cada solicitação de conteúdo completo:

```sql
CREATE TABLE capability_usage (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    capability_id  INTEGER NOT NULL
                   REFERENCES capability(id),
    requested_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Ao executar `get_capability`:

```text
resolve capability
      |
      v
INSERT capability_usage
      |
      v
return capability_detail
```

O total pode ser calculado quando necessário:

```sql
SELECT
    capability_id,
    COUNT(*) AS usage_count
FROM capability_usage
GROUP BY capability_id;
```

Esse registro significa: **o agente solicitou o conteúdo completo da capacidade para avaliar ou utilizá-la**.

`search_capabilities` não cria evento.

### Capacidades geradas

Quando nenhuma capacidade existente atende adequadamente à `NormalizedRequest`, o gerador pode produzir uma nova função reutilizável.

A função deve ser genérica e parametrizada. Valores específicos da requisição não devem ficar fixos no código reutilizável.

Exemplo:

```text
Requisição:
List directories inside ~/ambiente.

Nova capability:
list_subdirectories(base_path)

Invocação específica:
list_subdirectories "$HOME/ambiente"
```

Antes de entrar como ativa:

```text
generate
   |
   v
deduplicate
   |
   v
candidate
   |
   v
validate
   |
   v
active
```

A capability criada deve preencher também:

- `description`;
- `match_instruction`;
- `input_description`;
- `output_description`;
- contratos detalhados;
- código ou endereço;
- dependências;
- risco;
- origem `generated`.

Isso permite que uma requisição futura reutilize a função sem nova geração.

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
