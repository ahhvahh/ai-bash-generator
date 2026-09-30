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

O Capability Catalog MCP não recebe diretamente a frase original escrita pelo usuário.

Antes da consulta ao catálogo, a solicitação passa por um agente pequeno chamado inicialmente de `request-normalizer`.

Esse agente converte a solicitação para uma representação objetiva em inglês, separada em:

- input;
- processing;
- output;
- canonical instruction.

O inglês será utilizado como linguagem canônica interna do catálogo porque os comandos, nomes de ferramentas e documentação técnica utilizados pelo projeto normalmente já utilizam termos em inglês.

### Exemplo

Solicitação original:

```text
preciso listar as pastas que estão dentro da pasta ~/ambiente
```

Resultado esperado do `request-normalizer`:

```json
{
  "canonical_instruction": "List subdirectories in ~/ambiente.",
  "intent": "list_subdirectories",
  "input": [
    {
      "name": "base_path",
      "type": "path",
      "value": "~/ambiente"
    }
  ],
  "processing": [
    "Enumerate immediate child entries.",
    "Keep directories only."
  ],
  "output": [
    {
      "name": "directories",
      "type": "list<path>"
    }
  ]
}
```

O agente seguinte recebe essa estrutura e consulta os MCPs autorizados para descobrir uma função, script, aplicação ou serviço que possa atender ao requisito.

Fluxo:

```text
User text
   |
   v
request-normalizer
   |
   v
NormalizedRequest
   |
   | canonical English
   v
capability-discovery agent
   |
   v
Capability Catalog MCP
   |
   +--> function
   +--> script
   +--> application
   +--> service/address
   |
   v
selected capabilities
   |
   v
bash-generator
   |
   v
ScriptArtifact
```

O catálogo não deve executar a capacidade encontrada. Ele apenas descreve como ela funciona e como poderá ser utilizada pelo gerador.

### Ferramentas MCP

#### `search_capabilities`

Pesquisa capacidades usando a instrução normalizada.

Entrada sugerida:

```json
{
  "canonical_instruction": "List subdirectories in ~/ambiente.",
  "intent": "list_subdirectories",
  "input_types": ["path"],
  "output_types": ["list<path>"],
  "platform": "debian",
  "limit": 5
}
```

Resposta resumida:

```json
{
  "results": [
    {
      "id": "list-subdirectories",
      "type": "function",
      "description": "List immediate child directories of a given path.",
      "match_instruction": "List subdirectories in a directory."
    }
  ]
}
```

A resposta de `search_capabilities` deve ser propositalmente mínima para reduzir o número de tokens e simplificar a interpretação por modelos pequenos.

Cada resultado deve retornar somente:

- `id`;
- `type`;
- `description`;
- `match_instruction`.

Informações como versão, nome amigável, linguagem, complexidade, contador de uso, código, endereço, dependências, entradas e saídas não devem ser retornadas nessa etapa.

Depois que o agente selecionar um `id`, ele deve utilizar `get_capability` para obter a definição completa da capacidade.

#### `get_capability`

Entrada:

```json
{
  "id": "list-subdirectories",
  "version": 1
}
```

Resposta conceitual:

```json
{
  "id": "list-subdirectories",
  "version": 1,
  "type": "function",
  "name": "List Subdirectories",
  "description": "List immediate child directories of a given path.",
  "match_instruction": "List subdirectories in a directory.",
  "language": "bash",
  "source": "list_subdirectories() { find \"$1\" -mindepth 1 -maxdepth 1 -type d -print; }",
  "inputs": [
    {
      "name": "base_path",
      "type": "path",
      "required": true
    }
  ],
  "processing": [
    "Enumerate immediate child entries.",
    "Keep directories only."
  ],
  "outputs": [
    {
      "name": "directories",
      "type": "list<path>"
    }
  ],
  "dependencies": ["find"],
  "platforms": ["linux", "debian"],
  "risk_level": "read_only",
  "complexity_score": 1,
  "usage_count": 42
}
```

### Tipos de capacidade

Valores iniciais:

```text
function
script
application
service
```

Uma capacidade poderá entregar:

- código de função;
- caminho de um script;
- caminho de uma aplicação;
- endereço interno de serviço;
- informações de invocação.

### Banco de dados

O catálogo utilizará PostgreSQL.

A prioridade dessa estrutura é manter a consulta de `search_capabilities` sobre a menor quantidade possível de dados. Para isso, separar os dados em três grupos:

1. **índice de pesquisa**: somente os campos necessários para encontrar e apresentar uma capacidade;
2. **detalhes da capacidade**: carregados apenas depois que o agente escolher um `id`;
3. **estatísticas de uso**: mantidas fora da tabela de pesquisa para evitar atualizações frequentes nela.

Fluxo esperado:

```text
search_capabilities
        |
        v
capability
(id, type, description, match_instruction)
        |
        v
LLM escolhe um id
        |
        v
get_capability
        |
        v
capability_detail
```

#### Conexão

Para uma instalação local, preferir PostgreSQL através de Unix Domain Socket.

Exemplo de configuração:

```yaml
database:
  driver: postgres
  host: /var/run/postgresql
  database: ai_bash_gen
  user: ai_bash_gen
  sslmode: disable
```

A aplicação não deve depender de uma porta PostgreSQL exposta externamente.

### Tabela de pesquisa

A tabela `capability` deve permanecer pequena.

```sql
CREATE TABLE capability (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    capability_key    TEXT NOT NULL UNIQUE,

    type              SMALLINT NOT NULL,

    description       TEXT NOT NULL,

    match_instruction TEXT NOT NULL,

    intent            TEXT,

    enabled           BOOLEAN NOT NULL DEFAULT TRUE
);
```

Mapeamento sugerido para `type`:

```text
1 = function
2 = script
3 = application
4 = service
```

O uso de `SMALLINT` evita repetir strings como `function`, `script` e `application` em todas as linhas. O MCP converte esse valor para texto antes de responder ao agente.

A consulta de `search_capabilities` deve selecionar somente:

```sql
SELECT
    capability_key AS id,
    type,
    description,
    match_instruction
FROM capability
WHERE enabled = TRUE;
```

A resposta MCP continua mínima:

```json
{
  "results": [
    {
      "id": "list-subdirectories",
      "type": "function",
      "description": "List immediate child directories of a given path.",
      "match_instruction": "List subdirectories in a directory."
    }
  ]
}
```

Não incluir nessa consulta:

- código-fonte;
- endereço;
- argumentos;
- dependências;
- contador de uso;
- complexidade;
- timestamps;
- contratos de entrada e saída.

### Pesquisa textual

Como todas as instruções internas são normalizadas para inglês, utilizar o mecanismo nativo de Full Text Search do PostgreSQL.

Criar índice GIN por expressão sem adicionar uma coluna `tsvector` à tabela:

```sql
CREATE INDEX ix_capability_search
ON capability
USING GIN (
    to_tsvector(
        'english',
        coalesce(match_instruction, '') || ' ' ||
        coalesce(description, '')
    )
);
```

Para intenção exata:

```sql
CREATE INDEX ix_capability_intent
ON capability (intent)
WHERE enabled = TRUE;
```

A pesquisa deve priorizar:

1. correspondência exata de `intent`;
2. correspondência full-text de `match_instruction`;
3. correspondência full-text de `description`.

Exemplo conceitual:

```sql
SELECT
    capability_key AS id,
    type,
    description,
    match_instruction
FROM capability
WHERE
    enabled = TRUE
    AND (
        intent = $1
        OR
        to_tsvector(
            'english',
            coalesce(match_instruction, '') || ' ' ||
            coalesce(description, '')
        ) @@ websearch_to_tsquery('english', $2)
    )
LIMIT $3;
```

GIN é o tipo de índice preferido pelo PostgreSQL para Full Text Search em consultas frequentes.

### Tabela de detalhes

Os dados maiores ficam em uma tabela separada e não participam de `search_capabilities`.

```sql
CREATE TABLE capability_detail (
    capability_id     INTEGER PRIMARY KEY
                      REFERENCES capability(id)
                      ON DELETE CASCADE,

    version           SMALLINT NOT NULL DEFAULT 1,

    language          TEXT,

    input_contract    JSONB,
    processing        JSONB,
    output_contract   JSONB,

    source_code       TEXT,
    address           TEXT,
    invocation        JSONB,
    dependencies      JSONB,

    risk_level        SMALLINT NOT NULL DEFAULT 0,
    complexity_score  SMALLINT NOT NULL DEFAULT 1,

    checksum          TEXT
);
```

Mapeamento sugerido para `risk_level`:

```text
0 = read_only
1 = low
2 = medium
3 = high
```

`get_capability` deve localizar primeiro o ID interno pela chave e então buscar o detalhe pela chave primária.

Exemplo:

```sql
SELECT
    c.capability_key,
    c.type,
    c.description,
    c.match_instruction,
    d.version,
    d.language,
    d.input_contract,
    d.processing,
    d.output_contract,
    d.source_code,
    d.address,
    d.invocation,
    d.dependencies,
    d.risk_level,
    d.complexity_score,
    d.checksum
FROM capability c
JOIN capability_detail d
  ON d.capability_id = c.id
WHERE c.capability_key = $1
  AND c.enabled = TRUE;
```

Campos grandes, como `source_code`, permanecem fora da tabela de pesquisa. O PostgreSQL também pode comprimir ou mover valores grandes para armazenamento TOAST automaticamente, mantendo a linha principal menor.

### Estatísticas de uso

Não manter `usage_count` na tabela `capability`.

O contador muda com frequência e não participa da pesquisa MCP. Mantê-lo separado evita alterar constantemente as linhas utilizadas pelo índice de pesquisa.

```sql
CREATE TABLE capability_stats (
    capability_id INTEGER PRIMARY KEY
                  REFERENCES capability(id)
                  ON DELETE CASCADE,

    usage_count   BIGINT NOT NULL DEFAULT 0,

    last_used_at  TIMESTAMPTZ
);
```

Atualização:

```sql
INSERT INTO capability_stats (
    capability_id,
    usage_count,
    last_used_at
)
VALUES ($1, 1, now())

ON CONFLICT (capability_id)
DO UPDATE SET
    usage_count = capability_stats.usage_count + 1,
    last_used_at = EXCLUDED.last_used_at;
```

Uma capacidade é considerada utilizada somente quando:

1. foi selecionada pelo gerador;
2. aparece no `ScriptArtifact`;
3. o artefato foi validado;
4. a geração terminou com sucesso.

Consultar uma capacidade pelo MCP não incrementa o contador.

### Histórico opcional

O projeto precisa inicialmente do contador agregado, não de um registro permanente de cada consulta.

Caso seja necessário auditar usos individuais no futuro, criar uma tabela separada e opcional:

```sql
CREATE TABLE capability_usage_event (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    capability_id  INTEGER NOT NULL
                   REFERENCES capability(id),

    request_id     TEXT NOT NULL,

    agent_id       TEXT NOT NULL,

    used_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Essa tabela não deve participar das consultas do MCP e poderá possuir política de retenção.

### Estrutura final

```text
capability
    dados pequenos usados na pesquisa
        |
        +---- capability_detail
        |       dados completos, carregados sob demanda
        |
        +---- capability_stats
                contador e último uso

capability_usage_event
    opcional para auditoria
```

Essa separação mantém a operação mais frequente, `search_capabilities`, limitada a uma tabela pequena e indexada.

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
