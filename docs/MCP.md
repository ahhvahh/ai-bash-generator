# MCPs do AI Bash Generator

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

Objetivo: permitir que o agente descubra componentes reutilizáveis antes de gerar um script Bash.

O catálogo poderá representar:

- funções Bash;
- scripts;
- aplicações locais;
- comandos internos aprovados;
- serviços locais autorizados.

O MCP é consultivo. Ele não executa os componentes encontrados.

### Ferramentas

#### `search_capabilities`

Pesquisa capacidades compatíveis com uma necessidade descrita pelo agente.

Entrada conceitual:

```json
{
  "query": "compactar uma pasta mantendo permissões",
  "type": "function",
  "language": "bash",
  "platform": "debian",
  "limit": 5
}
```

Resposta conceitual:

```json
{
  "results": [
    {
      "id": "archive_directory",
      "version": 2,
      "type": "function",
      "name": "Archive Directory",
      "description": "Compacta um diretório preservando permissões.",
      "language": "bash",
      "complexity_score": 2,
      "usage_count": 31
    }
  ]
}
```

A pesquisa deve retornar somente informações resumidas. Código, argumentos completos e detalhes de invocação ficam para `get_capability`.

#### `get_capability`

Obtém a definição completa de uma capacidade.

Entrada:

```json
{
  "id": "archive_directory",
  "version": 2
}
```

Exemplo para uma função:

```json
{
  "id": "archive_directory",
  "version": 2,
  "type": "function",
  "language": "bash",
  "description": "Compacta um diretório preservando permissões.",
  "source": "archive_directory() { ... }",
  "inputs_schema": {},
  "outputs_schema": {},
  "dependencies": ["tar"],
  "platforms": ["linux", "debian"],
  "complexity_score": 2,
  "checksum": "sha256:..."
}
```

Exemplo para uma aplicação:

```json
{
  "id": "backup-manager",
  "version": 1,
  "type": "application",
  "description": "Aplicação local responsável por criação de backups.",
  "invocation": {
    "kind": "local-executable",
    "address": "/usr/local/bin/backup-manager",
    "arguments_schema": {}
  },
  "outputs_schema": {},
  "platforms": ["debian"],
  "complexity_score": 4
}
```

Exemplo para um script reutilizável:

```json
{
  "id": "rotate-backups",
  "version": 3,
  "type": "script",
  "description": "Rotaciona arquivos antigos de backup.",
  "invocation": {
    "kind": "local-script",
    "address": "/usr/local/lib/llama-agentd/scripts/rotate-backups.sh",
    "arguments_schema": {}
  }
}
```

### Banco de dados

Banco inicial:

```text
/var/lib/llama-agentd/catalog/capabilities.db
```

Registro conceitual:

```text
capabilities

id
version
type
name
language
description
source
invocation
inputs_schema
outputs_schema
tags
dependencies
platforms
complexity_score
enabled
checksum
created_at
updated_at
```

Tipos iniciais:

```text
function
script
application
```

### Telemetria

O número de consultas não representa uso real.

Uma capacidade é considerada utilizada somente quando:

1. o agente inclui a capacidade no `ScriptArtifact`;
2. o artefato é válido;
3. a capacidade e sua versão existem;
4. a geração termina com sucesso.

Banco de telemetria:

```text
/var/lib/llama-agentd/state/telemetry.db
```

Evento conceitual:

```text
capability_usage

id
capability_id
capability_version
request_id
agent_id
pipeline_id
used_at
```

Capacidades com uso elevado ou alta complexidade poderão gerar uma iniciativa para serem promovidas a aplicações ou scripts independentes.

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
/var/lib/llama-agentd/secrets/google-mail/
```

Permissões sugeridas:

```text
owner: llama-agentd
group: llama-agentd
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
llama-agentd mcp capability-catalog
llama-agentd mcp google-mail
```

O `capability-catalog` poderá operar totalmente local e sem rede.

O `google-mail` é uma exceção controlada: precisa de acesso à API do Google. Por isso, seu isolamento deverá ser tratado separadamente do processo de inferência.

Não ampliar o acesso de rede de todo o daemon apenas para permitir Gmail.

A implementação deve preferir separar o processo que acessa Google, com política de rede específica, mantendo o `llama-server` e os demais componentes sem acesso IP.

## 4. Configuração MCP

Arquivo sugerido:

```text
/etc/llama-agentd/mcp/servers.yaml
```

Exemplo:

```yaml
version: 1

servers:

  capability-catalog:
    enabled: true
    transport: stdio
    command: /usr/local/bin/llama-agentd
    args:
      - mcp
      - capability-catalog
      - --config
      - /etc/llama-agentd/config.yaml

  google-mail:
    enabled: false
    transport: stdio
    command: /usr/local/bin/llama-agentd
    args:
      - mcp
      - google-mail
      - --config
      - /etc/llama-agentd/config.yaml
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
