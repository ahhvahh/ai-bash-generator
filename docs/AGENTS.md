# Agentes

Este documento define como agentes são criados, configurados, validados e executados pelo `llama-agentd`.

## Objetivo

Um agente representa uma configuração reutilizável sobre o motor de inferência.

O agente não é um processo independente. Ele é uma definição carregada pelo daemon contendo:

- identidade;
- modelo;
- prompt de sistema;
- parâmetros de geração;
- formato de entrada;
- formato de saída;
- MCPs permitidos;
- limites;
- políticas de segurança.

A criação e alteração de agentes devem ser feitas preferencialmente pela própria aplicação, evitando edição manual incorreta de arquivos.

---

## 1. Comandos

### Criar agente

Modo interativo:

```bash
llama-agentd agent create
```

Modo não interativo:

```bash
llama-agentd agent create \
  --id bash-generator \
  --name "Gerador de Scripts Bash" \
  --model qwen2.5-coder-1.5b \
  --model-file /var/lib/llama-agentd/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf
```

### Listar agentes

```bash
llama-agentd agent list
```

### Exibir agente

```bash
llama-agentd agent show bash-generator
```

### Validar agente

```bash
llama-agentd agent validate bash-generator
```

### Editar agente

```bash
llama-agentd agent edit bash-generator
```

### Desabilitar

```bash
llama-agentd agent disable bash-generator
```

### Habilitar

```bash
llama-agentd agent enable bash-generator
```

### Remover

```bash
llama-agentd agent remove bash-generator
```

A remoção deve exigir confirmação explícita e criar backup da configuração.

---

## 2. Fluxo interativo de criação

Ao executar:

```bash
llama-agentd agent create
```

a aplicação deve solicitar:

```text
ID do agente:
Nome:
Descrição:
Modelo:
Arquivo GGUF:
Prompt:
Tipo de entrada:
Tipo de saída:
MCPs permitidos:
Temperatura:
Top P:
Máximo de tokens:
Timeout:
Máximo de tool calls:
Habilitar agente agora?:
```

Sempre que possível, apresentar valores sugeridos.

Antes de gravar:

1. validar ID;
2. verificar duplicidade;
3. verificar existência do modelo;
4. validar parâmetros;
5. validar MCPs;
6. validar schemas;
7. mostrar resumo;
8. pedir confirmação;
9. gravar atomicamente;
10. solicitar reload do daemon ou enviar sinal apropriado.

---

## 3. Local dos agentes

Diretório padrão:

```text
/etc/llama-agentd/agents/
```

Cada agente será armazenado em um arquivo YAML.

Exemplo:

```text
/etc/llama-agentd/agents/bash-generator.yaml
```

Arquivos devem possuir permissões que impeçam alteração por usuários não autorizados.

Sugestão:

```text
root:llama-agentd
0640
```

---

## 4. Schema conceitual

Exemplo completo:

```yaml
version: 1

id: bash-generator

name: Gerador de Scripts Bash

description: >
  Gera scripts Bash a partir de uma TaskSpec e pode consultar
  MCPs autorizados para localizar capacidades reutilizáveis ou
  obter informações necessárias.

enabled: true

model:
  name: qwen2.5-coder-1.5b
  file: /var/lib/llama-agentd/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf

generation:
  temperature: 0.1
  top_p: 0.9
  max_tokens: 4096

runtime:
  timeout: 120s
  max_tool_calls: 8

input:
  type: json_schema
  schema: task-spec

output:
  type: json_schema
  schema: script-artifact

tools:
  mcp:
    allowed:
      - capability-catalog
      - google-mail

prompt: |
  Você é um agente especializado em geração de scripts Bash.

  Sua entrada será uma TaskSpec validada.

  Antes de implementar lógica complexa, consulte o MCP
  capability-catalog para procurar funções, scripts ou aplicações
  reutilizáveis.

  Consulte o MCP google-mail somente quando a solicitação do usuário
  depender explicitamente de conteúdo de e-mail.

  Não consulte e-mails por curiosidade ou sem necessidade para a tarefa.

  Não execute scripts.
  Não execute comandos.
  Não altere o sistema.
  Não altere o catálogo.
  Não modifique e-mails.

  Gere um ScriptArtifact válido.

  Declare em capabilities_used somente as capacidades efetivamente
  incorporadas ou referenciadas no script final.
```

---

## 5. Agente inicial: request-organizer

ID:

```text
request-organizer
```

Responsabilidade:

transformar linguagem natural em `TaskSpec`.

Esse agente não precisa consultar MCPs na primeira versão.

Exemplo:

```yaml
version: 1

id: request-organizer

name: Organizador de Requisições

description: >
  Converte uma solicitação em linguagem natural para uma especificação
  técnica estruturada.

enabled: true

model:
  name: qwen2.5-1.5b-instruct
  file: /var/lib/llama-agentd/models/qwen2.5-1.5b-instruct-q4_k_m.gguf

generation:
  temperature: 0.1
  top_p: 0.9
  max_tokens: 1200

runtime:
  timeout: 60s
  max_tool_calls: 0

input:
  type: text

output:
  type: json_schema
  schema: task-spec

tools:
  mcp:
    allowed: []

prompt: |
  Transforme a solicitação do usuário em uma TaskSpec.

  Preserve requisitos informados.
  Não invente requisitos.
  Identifique informações ausentes.
  Não gere o script final.
```

---

## 6. Agente inicial: bash-generator

ID:

```text
bash-generator
```

Responsabilidade:

- receber uma `TaskSpec`;
- decidir se MCPs podem melhorar a resposta;
- pesquisar capacidades reutilizáveis;
- consultar e-mails apenas quando necessário;
- gerar um `ScriptArtifact`;
- declarar capacidades utilizadas.

### Ordem recomendada

```text
TaskSpec
   |
   v
analisar requisitos
   |
   +--> precisa de capacidade reutilizável?
   |        |
   |        v
   |   capability-catalog.search_capabilities
   |        |
   |        v
   |   capability-catalog.get_capability
   |
   +--> precisa de e-mail?
   |        |
   |        v
   |   google-mail.search_emails
   |        |
   |        v
   |   google-mail.get_email / get_thread
   |
   v
gerar ScriptArtifact
```

---

## 7. Política de consulta MCP

O agente não deve chamar tools sem motivo.

Regras:

### Capability Catalog

Consultar quando:

- uma operação é suficientemente genérica para provavelmente já existir;
- a TaskSpec exige integração com aplicação local;
- uma função complexa pode ser reutilizada;
- o script depende de comportamento já padronizado.

Não consultar repetidamente a mesma capability durante a mesma requisição sem necessidade.

### Google Mail

Consultar somente quando:

- o usuário pedir informação existente em e-mail;
- a TaskSpec indicar e-mail como fonte;
- o script necessitar de dados concretos presentes em uma mensagem.

Nunca utilizar Gmail para enriquecer genericamente uma resposta.

---

## 8. ScriptArtifact

Formato conceitual:

```json
{
  "version": "1.0",
  "language": "bash",
  "script": "#!/usr/bin/env bash\n...",
  "capabilities_used": [
    {
      "id": "archive_directory",
      "version": 2
    }
  ],
  "sources_used": [
    {
      "type": "email",
      "reference": "message:18f..."
    }
  ],
  "warnings": []
}
```

O campo `capabilities_used` será usado pela aplicação para telemetria.

O campo `sources_used` permite auditoria sem copiar conteúdo sensível para logs.

---

## 9. Segurança de MCP por agente

O agente somente poderá consultar MCPs declarados em:

```yaml
tools:
  mcp:
    allowed:
```

A aplicação deve rejeitar chamadas para MCPs não autorizados mesmo que o modelo tente produzi-las.

Exemplo:

```text
bash-generator
    allowed:
       capability-catalog
       google-mail

request-organizer
    allowed:
       nenhum
```

A autorização real é feita pelo `llama-agentd`, não pelo prompt.

---

## 10. Limites

Cada agente deve possuir limites explícitos:

```yaml
runtime:
  timeout: 120s
  max_tool_calls: 8
```

Também devem existir limites globais.

O valor efetivo deve ser o mais restritivo entre configuração global e configuração do agente.

Exemplo:

```text
global max_tool_calls = 10
agent max_tool_calls  = 8

efetivo = 8
```

---

## 11. Validação

Antes de disponibilizar um agente, validar:

- versão do schema;
- ID;
- nome;
- modelo;
- arquivo GGUF;
- parâmetros de geração;
- schema de entrada;
- schema de saída;
- MCPs permitidos;
- timeout;
- quantidade máxima de tool calls;
- prompt não vazio.

IDs devem seguir padrão simples:

```text
[a-z0-9][a-z0-9-]{1,62}
```

Exemplos válidos:

```text
bash-generator
request-organizer
log-analyzer
```

---

## 12. Gravação atômica

Ao criar ou alterar um agente:

```text
gerar conteúdo
      |
      v
validar
      |
      v
gravar arquivo temporário
      |
      v
fsync
      |
      v
chmod
      |
      v
rename atômico
```

Não deixar arquivo parcial em `/etc/llama-agentd/agents/`.

---

## 13. Reload

Após criar ou alterar agente:

```bash
llama-agentd agent create
```

a aplicação poderá:

1. validar toda a nova configuração;
2. enviar `SIGHUP` ao daemon;
3. aguardar confirmação de reload.

Se o reload falhar, a configuração ativa anterior deve continuar válida.

---

## 14. Pipeline padrão

Configuração conceitual:

```yaml
pipelines:

  script-builder:

    steps:

      - agent: request-organizer
        output_schema: task-spec

      - agent: bash-generator
        input: previous
```

Fluxo:

```text
usuário
  |
  v
request-organizer
  |
  v
TaskSpec
  |
  v
bash-generator
  |
  +--> MCP capability-catalog
  |
  +--> MCP google-mail, se necessário
  |
  v
ScriptArtifact
  |
  v
validação
  |
  v
script Bash
```

---

## 15. Criação futura de agentes especializados

A mesma estrutura permitirá agentes específicos, por exemplo:

```text
backup-script-generator
systemd-script-generator
network-diagnostics-generator
log-analysis-agent
email-driven-script-generator
```

Um agente especializado poderá:

- usar outro modelo;
- utilizar outro prompt;
- ter outros schemas;
- possuir outra allowlist de MCPs;
- possuir limites mais restritivos.

A aplicação continua responsável pelo controle e validação.
