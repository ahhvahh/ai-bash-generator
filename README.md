# ai-bash-gen

Aplicação e serviço para geração local de scripts Bash utilizando agentes baseados em LLM, `llama.cpp`, MCP (Model Context Protocol), Unix Domain Sockets e Protocol Buffers.

O objetivo é transformar uma solicitação em linguagem natural em um script Bash estruturado, reutilizando funções, aplicações e informações disponibilizadas por servidores MCP controlados pelo próprio ambiente.

## Objetivos

O projeto foi desenhado para:

- executar localmente em Debian/Linux;
- funcionar em hardware limitado, inicialmente com 2 núcleos de CPU e 8 GB de RAM;
- utilizar `llama.cpp` como motor de inferência;
- manter o `llama-server` isolado de TCP/IP e acessível somente pela aplicação;
- expor somente Unix Domain Sockets controlados por `ai-bash-gen`;
- utilizar Protocol Buffers como contrato e transporte estruturado entre componentes;
- utilizar Protobuf Text Format como representação estruturada e compacta na fronteira com os LLMs;
- permitir criação de agentes por configuração;
- permitir que agentes consultem servidores MCP autorizados;
- manter catálogo e telemetria de funções reutilizáveis;
- registrar logs estruturados no journald.

## Componentes

### `ai-bash-gen`

Daemon principal escrito em Go.

Responsabilidades:

- configuração e instalação;
- criação e carregamento de agentes;
- roteamento de requisições;
- execução de pipelines;
- comunicação com `llama-server`;
- validação de respostas;
- controle de acesso aos MCPs;
- telemetria;
- logs;
- segurança.

### `llama-server`

Motor de inferência fornecido pelo `llama.cpp`.

Será executado como processo gerenciado pelo `ai-bash-gen`, utilizando exclusivamente um Unix Domain Socket privado.

Exemplo:

```text
/run/ai-bash-gen/internal/llama.sock
```

Nenhuma porta TCP será exposta.

### Agentes

Agentes são definidos por arquivos de configuração e carregados dinamicamente.

Um agente contém, no mínimo:

- ID;
- nome;
- modelo;
- prompt de sistema;
- parâmetros de geração;
- MCPs permitidos;
- formato de entrada e saída.

A documentação detalhada está em [docs/AGENTS.md](docs/AGENTS.md).

A documentação completa e ordenada do processamento está em [docs/pipeline/](docs/pipeline/README.md).

Etapas:

1. [request-normalizer](docs/pipeline/01_REQUEST_NORMALIZER.md)
2. [NormalizedRequest](docs/pipeline/02_NORMALIZED_REQUEST.md)
3. [search_capabilities](docs/pipeline/03_SEARCH_CAPABILITIES.md)
4. [bash-generator](docs/pipeline/04_BASH_GENERATOR.md)
5. [validation](docs/pipeline/05_VALIDATION.md)
6. [bash-output](docs/pipeline/06_BASH_OUTPUT.md)

Referência de serialização: [Protobuf no pipeline](docs/pipeline/PROTOBUF.md).

Schema canônico: [proto/ai_bash_gen/v1/pipeline.proto](proto/ai_bash_gen/v1/pipeline.proto).

Revisão de arquitetura atual: [docs/analysis/ARCHITECTURE_REVIEW_V2.md](docs/analysis/ARCHITECTURE_REVIEW_V2.md).

Histórico V1: [docs/analysis/ARCHITECTURE_REVIEW.md](docs/analysis/ARCHITECTURE_REVIEW.md).

Diagramas de sequência: [docs/pipeline/SEQUENCE_DIAGRAMS.md](docs/pipeline/SEQUENCE_DIAGRAMS.md).

### MCP

Os servidores MCP fornecem capacidades consultivas aos agentes.

A primeira versão prevê dois MCPs:

1. **Capability Catalog MCP** — pesquisa funções, scripts e aplicações reutilizáveis.
2. **Google Mail MCP** — pesquisa e leitura controlada de mensagens de uma caixa Gmail autorizada.

A documentação está em [docs/MCP.md](docs/MCP.md).

## Arquitetura

```text
Cliente
   |
   | Protobuf
   v
/run/ai-bash-gen/routes/*.sock
   |
   v
ai-bash-gen
   |
   +-- Router
   +-- Agent Manager
   +-- Pipeline Manager
   +-- Tool/MCP Orchestrator
   |      |
   |      +--> Capability Catalog MCP
   |      +--> Google Mail MCP
   |
   +-- Schema Validator
   +-- Capability Publisher
   +-- Bash Output
   +-- Telemetry
   |
   | HTTP sobre Unix Socket
   v
/run/ai-bash-gen/internal/llama.sock
   |
   v
llama-server
```

## Pipeline inicial

```text
Solicitação do usuário
        |
        v
request-normalizer
        |
        v
NormalizedRequest
        |
        v
search_capabilities
        |
        v
bash-generator
        |
        +--> tool loop controlado pelo ai-bash-gen
        |
        v
GenerationPlan
        |
        v
validation
        |
        +--> Capability Publisher (idempotente)
        |
        v
bash-output
        |
        v
arquivo .sh
```

A aplicação transforma a solicitação em uma representação técnica curta em inglês, pesquisa capacidades reutilizáveis e usa o gerador para escolher uma existente ou produzir uma nova função parametrizada.

## Catálogo de funções

O Capability Catalog armazenará funções reutilizáveis, incluindo:

- identificador;
- versão;
- linguagem;
- descrição;
- instrução de correspondência;
- descrição resumida da entrada;
- descrição resumida da saída;
- implementação;
- contratos detalhados de entrada e saída;
- dependências;
- plataformas suportadas;
- complexidade;
- checksum.

Cada chamada de `get_capability` será registrada em uma tabela append-only, permitindo medir quais capacidades são consultadas em profundidade pelos agentes.

Funções muito utilizadas ou de alta complexidade poderão gerar uma iniciativa para transformação em aplicação ou script independente.

## Estrutura de diretórios planejada

```text
/etc/ai-bash-gen/
├── config.yaml
├── agents/
├── schemas/
└── mcp/

/var/lib/ai-bash-gen/
├── models/
├── catalog/
└── state/

/run/ai-bash-gen/
├── routes/
└── internal/
    └── llama.sock
```

## Instalação e configuração

O executável deverá possuir um assistente interativo:

```bash
ai-bash-gen --configure
```

O assistente será responsável por sugerir caminhos compatíveis com Debian, criar o usuário de serviço, configurar permissões, copiar os binários e instalar a unidade systemd.

Execução normal:

```bash
ai-bash-gen --config /etc/ai-bash-gen/config.yaml
```

Validação:

```bash
ai-bash-gen validate --config /etc/ai-bash-gen/config.yaml
ai-bash-gen validate-security
```

## Segurança

Princípios iniciais:

- daemon executado como usuário de serviço dedicado;
- sem execução normal como root;
- `llama-server` sem interface TCP;
- sockets internos protegidos;
- clientes acessam somente `/run/ai-bash-gen/routes/`;
- MCPs definidos por allowlist;
- funções MCP de catálogo são somente leitura;
- scripts gerados não são executados automaticamente;
- respostas do LLM são validadas;
- prompts completos não são gravados em logs por padrão;
- uso de `PrivateNetwork=yes` e `RestrictAddressFamilies=AF_UNIX` quando compatível.

## Logs

A aplicação utilizará `log/slog` e enviará logs estruturados para stdout/stderr.

O systemd encaminhará os logs para journald:

```bash
journalctl -u ai-bash-gen
journalctl -u ai-bash-gen -f
```

## Estado do projeto

O projeto está atualmente em fase de definição de arquitetura e contratos.

Próximas etapas:

- definir schemas de configuração;
- implementar o modo `--configure`;
- implementar o daemon e protocolo Protobuf;
- implementar gerenciamento de agentes;
- implementar Capability Catalog MCP;
- implementar Google Mail MCP;
- integrar `llama.cpp`;
- adicionar testes de segurança e integração.


## Cliente de geração e observabilidade

A entrada externa de geração é um Unix Domain Socket:

```text
/run/ai-bash-gen/routes/generate.sock
```

O contrato está em `proto/ai_bash_gen/v1/generation_service.proto`. Uma conexão recebe um `GenerateRequest` e o servidor responde com uma sequência de `GenerateEvent`: eventos de progresso por estágio e, ao final, um `GenerateResult`.

O cliente oficial está no repositório `ai-bash-generator-client`. O cliente é responsável por gravar o artefato no filesystem do usuário; o daemon retorna somente `filename`, conteúdo e SHA-256.

Estado atual: o transporte Unix Socket, o streaming de progresso e um pipeline mínimo funcional estão implementados. O daemon valida as dependências antes de publicar `generate.sock`, inicia o `llama-server` em `/run/ai-bash-gen/internal/llama.sock`, aguarda `/health` ficar pronto, gera o Bash via `/v1/chat/completions`, valida a sintaxe com `bash -n` e retorna o artefato ao cliente. Se a primeira geração falhar no `bash -n`, o pipeline envia o erro de validação de volta ao LLM e solicita uma nova geração do zero; são permitidas até 2 tentativas dentro do timeout da requisição.

O estágio `search_capabilities` ainda opera em modo mínimo, sem catálogo MCP/PostgreSQL; a integração completa do catálogo continua sendo uma evolução separada.



### Logs estruturados no journald

O serviço systemd envia `stdout` e `stderr` para o journald e instala, por padrão:

```text
AI_BASH_GEN_LOG_LEVEL=debug
AI_BASH_GEN_LLAMA_LOG_VERBOSITY=5
```

Cada requisição recebe um `request_id`. O journal registra recebimento, início/fim de cada etapa, duração em milissegundos, chamada HTTP ao `llama-server`, status HTTP, uso de tokens quando informado pelo servidor, `finish_reason`, detecção de limite de tokens, validação `bash -n`, tentativas de regeneração, SHA-256 do artefato e duração total. Os eventos `generation_validation_failed` e `generation_retry_requested` deixam explícito quando uma saída inválida foi devolvida ao LLM para correção.

A etapa `search-capabilities` ainda não consulta PostgreSQL. Enquanto essa integração estiver pendente, o log registra explicitamente:

```text
event=database_stage_not_implemented
stage=search-capabilities
database=postgresql
database_query_executed=false
capability_catalog=in_development
```

Acompanhamento em tempo real:

```bash
sudo journalctl -u ai-bash-gen -f -o short-precise --no-pager
```

## Build, instalação e testes de aceitação

O build gera o daemon e o utilitário de smoke test para a mesma arquitetura:

```bash
./build.sh amd64
```

Artefatos principais:

```text
bin/amd64/
├── ai-bash-gen
├── ai-bash-gen-generation-test
├── install-binary.sh
├── test-binary.sh
└── test-generation.sh
```

O instalador valida explicitamente que o binário expõe:

```text
generate_socket=/run/ai-bash-gen/routes/generate.sock
```

Antes da instalação, em Debian/derivados, ele verifica os pacotes necessários ao instalador e aos testes de aceitação:

```text
bash coreutils grep mawk passwd util-linux libc-bin systemd file binutils findutils
```

Se algum estiver ausente, o instalador oferece executar `apt-get update` e `apt-get install`.

Antes de continuar a configuração do serviço, o instalador procura um `llama-server` compatível. Se não encontrar, ele oferece instalar automaticamente o componente usado pelo projeto: `llama.cpp v0.5.0`, fixado no commit `7fe450e19305b828c199d602c23a8337aaa1f03b`. A instalação automática adiciona, quando necessário, `git`, `cmake`, `build-essential` e `ca-certificates`, baixa o código-fonte oficial, compila somente o target `llama-server` em modo Release/CPU e com bibliotecas internas estáticas, e instala o resultado em `/usr/local/lib/ai-bash-gen/llama-server`.

O `llama-server` não recebe uma unit systemd independente: seu processo é iniciado, monitorado e encerrado pelo próprio `ai-bash-gen`, que o mantém restrito ao Unix Domain Socket privado `/run/ai-bash-gen/internal/llama.sock`. Para o caso de uso de geração de Bash, o runtime é iniciado com `--reasoning off`; isso evita consumir grande parte do orçamento de tokens com raciocínio interno antes do código e reduz o risco de a resposta ser cortada por `max_tokens`.

Se nenhum GGUF local for encontrado, o instalador mostra o hardware detectado e oferece um catálogo curado de modelos executáveis em máquinas com poucos recursos. O padrão é `Qwen3.5-0.8B Q4_0` (~563 MB), por ser atual e adequado ao perfil de laptop com cerca de 8 GB de RAM e CPU de poucos núcleos. Também estão disponíveis `Qwen3.5-0.8B Q8_0`, `Qwen2.5-Coder-1.5B-Instruct Q4_K_M` e `Qwen3.5-4B Q4_K_M`. Os downloads são feitos por HTTPS, gravados em `/var/lib/ai-bash-gen/models/model.gguf` e só são aceitos depois da validação SHA-256 e da assinatura `GGUF`.

A instalação totalmente automática usa:

```bash
./install-binary.sh --force
# ou
./install-binary.sh ./bin/amd64/ai-bash-gen --force
```

Com `--force`, o instalador não solicita confirmações e aplica os valores padrão: instala dependências ausentes, instala/reutiliza `llama.cpp`, baixa o modelo padrão quando necessário, instala a conta de serviço, instala a unit systemd, habilita no boot e inicia/reinicia o serviço. Se o binário instalado for diferente do novo, ele cria backup e substitui automaticamente; se o SHA-256 for igual, apenas reutiliza o binário já instalado. Usuário e grupo de serviço existentes são detectados via `getent` e reutilizados sem exclusão ou recriação. Configurações funcionais já existentes são preservadas.

O instalador também permite informar um usuário cliente. Esse usuário é incluído no grupo do serviço para conseguir atravessar `/run/ai-bash-gen/routes` e abrir sockets com modo `0660`. A nova associação de grupo requer uma nova sessão do usuário.

Ao instalar a unit systemd, o instalador pergunta se deve iniciar/reiniciar o serviço e se deve habilitá-lo no boot. Quando a inicialização é solicitada, ele aguarda até 180 segundos para permitir o carregamento inicial do modelo, confirma que o serviço permaneceu ativo e valida todos os sockets públicos declarados por `--show-paths` dentro de `/run/ai-bash-gen/routes/`, incluindo existência, modo `0660` e grupo do serviço. Se alguma rota não aparecer, a instalação falha e imprime `systemctl status` e as últimas mensagens do `journalctl`.

Os caminhos informados ao instalador para executável, configuração, estado, runtime e unit systemd devem ser absolutos. Valores relativos como `s`, `./ai-bash-gen` ou `bin/ai-bash-gen` são recusados e o instalador solicita novamente o campo. Quando um runtime diferente do padrão é escolhido, ele é propagado para a unit através de `AI_BASH_GEN_RUNTIME_DIR` e também é usado na validação das rotas.

O cadastro do usuário cliente também é validado em duas camadas. Primeiro, o instalador confirma via `id` que o usuário realmente pertence ao grupo do serviço após `usermod -aG`. Depois que as rotas estão disponíveis, ele usa `runuser` para iniciar uma sessão nova desse usuário e verifica acesso de travessia ao runtime e permissão de escrita nos sockets públicos. Se o cadastro estiver correto, mas a sessão que executou o instalador ainda não tiver carregado o novo grupo, o instalador não altera a sessão pai (isso não é possível de forma segura); ele exibe um aviso explícito solicitando `newgrp <grupo>` ou logout/login antes de usar o cliente.

### Teste do binário e do socket

```bash
./bin/amd64/test-binary.sh ./bin/amd64/ai-bash-gen
```

Além dos testes ELF/CLI, o teste sobe o daemon em um runtime temporário e verifica:

- criação de `generate.sock`;
- modo `0660` do socket;
- modo `0750` do diretório `routes`;
- presença de `generate_socket` em `--show-paths` e nos logs;
- encerramento gracioso via `SIGTERM`;
- presença dos componentes/pacotes usados pelo instalador e testes.

### Smoke test de geração

O pacote inclui 10 solicitações predefinidas, em ordem de complexidade crescente. Os scripts retornados **não são executados**. Para cada caso são verificados:

- todas as cinco etapas do pipeline concluídas com `OK`;
- filename seguro;
- SHA-256, quando informado pelo servidor;
- sintaxe com `bash -n`;
- presença dos comandos que a própria solicitação exigiu.

Executar todos os casos:

```bash
./bin/amd64/test-generation.sh
```

Usar outro socket:

```bash
./bin/amd64/test-generation.sh --socket /run/ai-bash-gen/routes/generate.sock
```

Executar um único caso:

```bash
./bin/amd64/test-generation.sh --case 06-tar-backup
```

Casos atuais:

1. `echo`;
2. `pwd`;
3. `ls -la`;
4. `df -h`;
5. `find + sort + head`;
6. backup de `/etc` com `tar`;
7. consulta de serviço com `systemctl is-active`;
8. processamento de `/etc/passwd` com `awk + sort + uniq`;
9. sincronização segura com `rsync --dry-run`;
10. backup robusto com `set -Eeuo pipefail`, `trap`, `mktemp`, `tar` e `sha256sum`.

O smoke test agora espera o pipeline funcional. Se o `llama-server`, o modelo GGUF ou o `bash` não estiverem disponíveis, o daemon encerra antes de criar `generate.sock`.

A configuração mínima é:

```yaml
llama:
  binary: /usr/local/lib/ai-bash-gen/llama-server
  model: /var/lib/ai-bash-gen/models/model.gguf
  context_size: 2048
  startup_timeout: 2m
  request_timeout: 3m
  max_tokens: 1536
  temperature: 0.2
```

A validação pode ser executada sem iniciar o daemon:

```bash
ai-bash-gen --config /etc/ai-bash-gen/config.yaml --check-dependencies
```

O instalador detecta um `llama-server` existente e confirma suporte a Unix Domain Socket. Se ele estiver ausente, o próprio instalador oferece compilar e instalar a versão fixada do `llama.cpp` antes de prosseguir. Depois disso, exige um arquivo `.gguf`, copia o runtime e o modelo para caminhos controlados pelo serviço e executa a mesma validação Go usando o usuário de serviço. Se qualquer dependência estiver ausente ou incompatível, a instalação/inicialização é interrompida antes da publicação das rotas.
