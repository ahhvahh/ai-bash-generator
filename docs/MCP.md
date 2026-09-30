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

Banco:

```text
/var/lib/ai-bash-gen/catalog/capabilities.db
```

A tabela principal deve armazenar o contrato da capacidade e também texto preparado para pesquisa.

Estrutura recomendada:

```sql
CREATE TABLE capabilities (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,

    capability_key      TEXT NOT NULL,
    version             INTEGER NOT NULL DEFAULT 1,

    type                TEXT NOT NULL
                        CHECK (type IN ('function','script','application','service')),

    name                TEXT NOT NULL,

    description_en      TEXT NOT NULL,
    match_instruction_en TEXT NOT NULL,
    intent              TEXT,

    language            TEXT,
    platform_json       TEXT NOT NULL DEFAULT '[]',
    keywords_json       TEXT NOT NULL DEFAULT '[]',

    input_json          TEXT NOT NULL DEFAULT '[]',
    processing_json     TEXT NOT NULL DEFAULT '[]',
    output_json         TEXT NOT NULL DEFAULT '[]',

    source_code         TEXT,
    address             TEXT,
    invocation_json     TEXT,

    dependencies_json   TEXT NOT NULL DEFAULT '[]',

    risk_level          TEXT NOT NULL DEFAULT 'read_only'
                        CHECK (risk_level IN (
                            'read_only',
                            'low',
                            'medium',
                            'high'
                        )),

    complexity_score    INTEGER NOT NULL DEFAULT 1
                        CHECK (complexity_score BETWEEN 1 AND 5),

    enabled             INTEGER NOT NULL DEFAULT 1
                        CHECK (enabled IN (0,1)),

    usage_count         INTEGER NOT NULL DEFAULT 0,
    last_used_at        TEXT,

    checksum            TEXT,

    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,

    UNIQUE (capability_key, version)
);
```

### Função dos principais campos

| Campo | Finalidade |
|---|---|
| `capability_key` | Identificador estável, por exemplo `list-subdirectories`. |
| `type` | Diferencia função, script, aplicação ou serviço. |
| `description_en` | Descrição humana objetiva da capacidade. |
| `match_instruction_en` | Frase canônica usada para aproximar a solicitação normalizada da capacidade. |
| `intent` | Intenção curta e estável, como `list_subdirectories`. |
| `keywords_json` | Sinônimos e termos úteis à pesquisa. |
| `input_json` | Contrato das entradas. |
| `processing_json` | Etapas conceituais realizadas pela capacidade. |
| `output_json` | Contrato da saída. |
| `source_code` | Código quando a capacidade for uma função incorporável. |
| `address` | Caminho ou endereço quando for script, aplicação ou serviço. |
| `invocation_json` | Forma segura de invocação e argumentos suportados. |
| `risk_level` | Indica o impacto esperado da capacidade. |
| `complexity_score` | Complexidade de 1 a 5. |
| `usage_count` | Contador agregado de uso efetivo. |

### Por que entradas, processamento e saídas ficam em JSON

A estrutura varia bastante entre capacidades.

Uma função pode receber somente um caminho:

```json
[
  {
    "name": "base_path",
    "type": "path",
    "required": true
  }
]
```

Outra aplicação pode receber vários parâmetros.

Usar JSON permite evoluir o contrato sem criar uma nova coluna para cada argumento.

O Go deve validar esses campos antes de persistir os dados.

### Busca textual

Na primeira versão, evitar embeddings.

Criar um índice SQLite FTS5 contendo principalmente:

- `name`;
- `description_en`;
- `match_instruction_en`;
- `intent`;
- keywords normalizadas.

Exemplo conceitual:

```sql
CREATE VIRTUAL TABLE capabilities_fts USING fts5(
    capability_key UNINDEXED,
    name,
    description_en,
    match_instruction_en,
    intent,
    keywords
);
```

A busca poderá priorizar nesta ordem:

1. `intent` exato;
2. `match_instruction_en`;
3. nome;
4. palavras-chave;
5. descrição.

Assim, a requisição:

```text
List subdirectories in ~/ambiente.
```

pode ser comparada com:

```text
List subdirectories in a directory.
```

sem depender de um modelo de embeddings.

### Exemplo de registro

```sql
INSERT INTO capabilities (
    capability_key,
    version,
    type,
    name,
    description_en,
    match_instruction_en,
    intent,
    language,
    platform_json,
    keywords_json,
    input_json,
    processing_json,
    output_json,
    source_code,
    dependencies_json,
    risk_level,
    complexity_score,
    created_at,
    updated_at
)
VALUES (
    'list-subdirectories',
    1,
    'function',
    'List Subdirectories',
    'List immediate child directories of a given path.',
    'List subdirectories in a directory.',
    'list_subdirectories',
    'bash',
    '["linux","debian"]',
    '["list directory","subdirectory","folder","find directories"]',
    '[{"name":"base_path","type":"path","required":true}]',
    '["Enumerate immediate child entries.","Keep directories only."]',
    '[{"name":"directories","type":"list<path>"}]',
    'list_subdirectories() { find "$1" -mindepth 1 -maxdepth 1 -type d -print; }',
    '["find"]',
    'read_only',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);
```

### Telemetria

`usage_count` é apenas uma métrica agregada para consulta rápida.

Manter também histórico individual em tabela separada:

```sql
CREATE TABLE capability_usage (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,

    capability_id       INTEGER NOT NULL,
    capability_version  INTEGER NOT NULL,

    request_id          TEXT NOT NULL,
    agent_id            TEXT NOT NULL,
    pipeline_id         TEXT,

    used_at             TEXT NOT NULL,

    FOREIGN KEY (capability_id)
        REFERENCES capabilities(id)
);
```

Uma capacidade é considerada utilizada somente quando:

1. foi selecionada pelo gerador;
2. aparece no `ScriptArtifact`;
3. o artefato foi validado;
4. a geração terminou com sucesso.

Consultar uma capacidade pelo MCP não incrementa `usage_count`.

Depois do uso efetivo, o `ai-bash-gen` deverá:

```text
insert capability_usage
        |
        v
increment capabilities.usage_count
        |
        v
update last_used_at
        |
        v
evaluate promotion policy
```

Capacidades muito utilizadas ou complexas poderão gerar uma iniciativa para serem transformadas em aplicação ou script dedicado.

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
