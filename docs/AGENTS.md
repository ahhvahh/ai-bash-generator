# Agentes

O fluxo completo de execução está documentado em [pipeline/README.md](pipeline/README.md).

Este documento define como agentes são criados, configurados, validados e executados pelo `ai-bash-gen`.

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
ai-bash-gen agent create
```

Modo não interativo:

```bash
ai-bash-gen agent create \
  --id bash-generator \
  --name "Gerador de Scripts Bash" \
  --model qwen2.5-coder-1.5b \
  --model-file /var/lib/ai-bash-gen/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf
```

### Listar agentes

```bash
ai-bash-gen agent list
```

### Exibir agente

```bash
ai-bash-gen agent show bash-generator
```

### Validar agente

```bash
ai-bash-gen agent validate bash-generator
```

### Editar agente

```bash
ai-bash-gen agent edit bash-generator
```

### Desabilitar

```bash
ai-bash-gen agent disable bash-generator
```

### Habilitar

```bash
ai-bash-gen agent enable bash-generator
```

### Remover

```bash
ai-bash-gen agent remove bash-generator
```

A remoção deve exigir confirmação explícita e criar backup da configuração.

---

## 2. Fluxo interativo de criação

Ao executar:

```bash
ai-bash-gen agent create
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
/etc/ai-bash-gen/agents/
```

Cada agente será armazenado em um arquivo YAML.

Exemplo:

```text
/etc/ai-bash-gen/agents/bash-generator.yaml
```

Arquivos devem possuir permissões que impeçam alteração por usuários não autorizados.

Sugestão:

```text
root:ai-bash-gen
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
  Gera scripts Bash a partir de uma NormalizedRequest e pode consultar
  MCPs autorizados para localizar capacidades reutilizáveis ou
  obter informações necessárias.

enabled: true

model:
  name: qwen2.5-coder-1.5b
  file: /var/lib/ai-bash-gen/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf

generation:
  temperature: 0.1
  top_p: 0.9
  max_tokens: 4096

runtime:
  timeout: 120s
  max_tool_calls: 8

input:
  type: protobuf_text
  message: ai_bash_gen.v1.NormalizedRequest

output:
  type: protobuf_text
  message: ai_bash_gen.v1.GenerationResult

tools:
  mcp:
    allowed:
      - capability-catalog
      - google-mail

prompt: |
  Você é um agente especializado em geração de scripts Bash.

  Sua entrada será uma NormalizedRequest validada.

  Antes de implementar lógica complexa, consulte o MCP
  capability-catalog para procurar funções, scripts ou aplicações
  reutilizáveis.

  Compare os candidatos usando objetivo, entrada e saída.

  Se nenhuma capability atender adequadamente à NormalizedRequest,
  gere uma nova função reutilizável e parametrizada.

  Não fixe na função reutilizável valores específicos da requisição.
  Separe a capability genérica da invocação atual.

  A nova capability deve possuir:
  - description;
  - match_instruction;
  - input_description;
  - output_description;
  - contratos detalhados de entrada e saída;
  - implementação;
  - dependências.

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

## 5. Configuração do modelo GGUF e perfil de hardware

O `ai-bash-gen` deverá aceitar arquivos de modelo no formato GGUF e traduzir a configuração do agente para argumentos suportados pelo `llama-server`.

O arquivo deve existir localmente, ser legível pelo usuário de serviço e permanecer fora de diretórios graváveis por clientes.

Diretório recomendado:

```text
/var/lib/ai-bash-gen/models/
```

Exemplo de modelo:

```text
/var/lib/ai-bash-gen/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf
```

### Exemplo completo de configuração GGUF

```yaml
model:
  name: qwen2.5-coder-1.5b
  format: gguf
  file: /var/lib/ai-bash-gen/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf

  # Opcional. Se informado, deve ser validado antes de carregar o modelo.
  sha256: ""

  llama:
    profile: cpu

    context_size: 4096

    threads: 2
    threads_batch: 2

    device: none
    gpu_layers: 0

    batch_size: 512
    ubatch_size: 128

    flash_attention: auto
```

Mapeamento esperado para `llama-server`:

```text
model.file            -> --model
context_size          -> --ctx-size
threads               -> --threads
threads_batch         -> --threads-batch
device                -> --device
gpu_layers            -> --n-gpu-layers
batch_size            -> --batch-size
ubatch_size           -> --ubatch-size
flash_attention       -> --flash-attn
```

O programa não deve permitir que parâmetros genéricos ou `extra_args` substituam valores de segurança como `--host`, MCPs autorizados ou exposição de rede.

### Perfil padrão: CPU

Este deve ser o perfil inicial recomendado para a máquina de referência do projeto, com 2 núcleos e 8 GB de RAM:

```yaml
model:
  name: qwen2.5-coder-1.5b
  format: gguf
  file: /var/lib/ai-bash-gen/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf

  llama:
    profile: cpu

    context_size: 4096

    threads: 2
    threads_batch: 2

    device: none
    gpu_layers: 0

    batch_size: 512
    ubatch_size: 128

    flash_attention: auto
```

Com esse perfil, o comando equivalente deve conter aproximadamente:

```text
--model <arquivo.gguf>
--ctx-size 4096
--threads 2
--threads-batch 2
--device none
--n-gpu-layers 0
--batch-size 512
--ubatch-size 128
--flash-attn auto
```

O perfil CPU deve ser usado quando:

- nenhuma GPU compatível estiver disponível;
- o binário do `llama.cpp` não possuir backend GPU;
- o administrador selecionar explicitamente CPU;
- a GPU não tiver memória suficiente para offload seguro.

### Perfil padrão: GPU

Para uma única GPU compatível:

```yaml
model:
  name: qwen2.5-coder-1.5b
  format: gguf
  file: /var/lib/ai-bash-gen/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf

  llama:
    profile: gpu

    context_size: 4096

    threads: 2
    threads_batch: 2

    # "default" é um valor do ai-bash-gen.
    # Ele significa não forçar --device e utilizar o dispositivo
    # padrão detectado pelo llama.cpp.
    device: default

    gpu_layers: auto

    fit: true
    fit_target_mib: 1024

    main_gpu: 0
    split_mode: none

    flash_attention: auto
```

Mapeamento adicional:

```text
gpu_layers            -> --n-gpu-layers
fit: true             -> --fit on
fit_target_mib        -> --fit-target
main_gpu              -> --main-gpu
split_mode            -> --split-mode
```

Para o perfil GPU, o comando equivalente deve conter aproximadamente:

```text
--model <arquivo.gguf>
--ctx-size 4096
--threads 2
--threads-batch 2
--n-gpu-layers auto
--fit on
--fit-target 1024
--main-gpu 0
--split-mode none
--flash-attn auto
```

Quando `device: default` for utilizado, o `ai-bash-gen` não deve adicionar `--device`; o `llama.cpp` selecionará o dispositivo padrão disponível.

### Detecção de GPU

Durante `--configure`, `agent create` e `agent validate`, a aplicação deverá executar de forma controlada:

```bash
llama-server --list-devices
```

e interpretar os dispositivos retornados.

O assistente deverá apresentar algo semelhante a:

```text
Dispositivos de inferência encontrados:

[1] CPU
[2] CUDA0 - NVIDIA ...
[3] Vulkan0 - ...

Perfil sugerido: GPU
```

A presença de uma GPU no sistema não é suficiente. O binário do `llama.cpp` precisa ter sido compilado com um backend compatível com esse dispositivo.

Se nenhum dispositivo GPU utilizável for encontrado, selecionar automaticamente o perfil CPU.

### Perfil automático

Também deverá ser permitido:

```yaml
llama:
  profile: auto
```

Nesse modo:

1. executar a detecção de dispositivos;
2. preferir GPU quando houver backend compatível;
3. utilizar `gpu_layers: auto`;
4. manter `fit: true`;
5. utilizar CPU caso a GPU não esteja disponível;
6. registrar no journald qual perfil efetivo foi selecionado.

O perfil efetivo deverá aparecer em comandos de diagnóstico:

```bash
ai-bash-gen agent show bash-generator
```

Exemplo:

```text
Configured profile: auto
Effective profile:  gpu
Device:             CUDA0
GPU layers:         auto
Context:            4096
Threads:            2
```

### Validação do GGUF

Antes de ativar um agente, verificar:

- arquivo existente;
- arquivo regular;
- extensão `.gguf`;
- leitura pelo usuário `ai-bash-gen`;
- tamanho maior que zero;
- caminho dentro de um diretório de modelos autorizado;
- SHA-256, quando configurado;
- carregamento reconhecido pelo `llama.cpp`.

O `ai-bash-gen` não deve baixar modelos automaticamente durante a execução normal do serviço.

---

## 6. Agente inicial: request-normalizer

ID:

```text
request-normalizer
```

Responsabilidade:

transformar linguagem natural em `NormalizedRequest`.

Esse agente não precisa consultar MCPs na primeira versão.

Exemplo:

```yaml
version: 1

id: request-normalizer

name: Organizador de Requisições

description: >
  Converte uma solicitação em linguagem natural para uma especificação
  técnica estruturada.

enabled: true

model:
  name: qwen2.5-1.5b-instruct
  file: /var/lib/ai-bash-gen/models/qwen2.5-1.5b-instruct-q4_k_m.gguf

generation:
  temperature: 0.1
  top_p: 0.9
  max_tokens: 1200

runtime:
  timeout: 60s
  max_tool_calls: 0

input:
  type: protobuf_text
  message: ai_bash_gen.v1.UserRequest

output:
  type: protobuf_text
  message: ai_bash_gen.v1.NormalizedRequest

tools:
  mcp:
    allowed: []

prompt: |
  Transforme a solicitação do usuário em uma NormalizedRequest.

  Preserve requisitos informados.
  Não invente requisitos.
  Identifique informações ausentes.
  Não gere o script final.
```

---

## 7. Agente inicial: bash-generator

ID:

```text
bash-generator
```

Responsabilidade:

- receber uma `NormalizedRequest`;
- decidir se MCPs podem melhorar a resposta;
- pesquisar capacidades reutilizáveis;
- consultar e-mails apenas quando necessário;
- gerar um `ScriptArtifact`;
- declarar capacidades utilizadas.

### Ordem recomendada

```text
NormalizedRequest
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

## 8. Política de consulta MCP

O agente não deve chamar tools sem motivo.

Regras:

### Capability Catalog

Consultar quando:

- uma operação é suficientemente genérica para provavelmente já existir;
- a NormalizedRequest exige integração com aplicação local;
- uma função complexa pode ser reutilizada;
- o script depende de comportamento já padronizado.

Não consultar repetidamente a mesma capability durante a mesma requisição sem necessidade.

### Google Mail

Consultar somente quando:

- o usuário pedir informação existente em e-mail;
- a NormalizedRequest indicar e-mail como fonte;
- o script necessitar de dados concretos presentes em uma mensagem.

Nunca utilizar Gmail para enriquecer genericamente uma resposta.

---

## 9. ScriptArtifact

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

O campo `capabilities_used` registra quais capacidades foram incorporadas ao resultado.

A telemetria de acesso ao catálogo ocorre quando o agente chama `get_capability`, que gera um registro append-only no banco.

Quando uma nova função reutilizável for criada, o artefato poderá incluir também uma `generated_capability`, que será validada e deduplicada antes de entrar no catálogo.

O campo `sources_used` permite auditoria sem copiar conteúdo sensível para logs.

---

## 10. Segurança de MCP por agente

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

request-normalizer
    allowed:
       nenhum
```

A autorização real é feita pelo `ai-bash-gen`, não pelo prompt.

---

## 11. Limites

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

## 12. Validação

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
request-normalizer
log-analyzer
```

---

## 13. Gravação atômica

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

Não deixar arquivo parcial em `/etc/ai-bash-gen/agents/`.

---

## 14. Reload

Após criar ou alterar agente:

```bash
ai-bash-gen agent create
```

a aplicação poderá:

1. validar toda a nova configuração;
2. enviar `SIGHUP` ao daemon;
3. aguardar confirmação de reload.

Se o reload falhar, a configuração ativa anterior deve continuar válida.

---

## 15. Pipeline padrão

Configuração conceitual:

```yaml
pipelines:

  script-builder:

    steps:

      - agent: request-normalizer
        output_schema: normalized-request

      - agent: bash-generator
        input: previous
```

Fluxo:

```text
usuário
  |
  v
request-normalizer
  |
  v
NormalizedRequest
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

## 16. Criação futura de agentes especializados

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
