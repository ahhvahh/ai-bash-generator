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
- utilizar Protocol Buffers como protocolo entre clientes e o daemon;
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

O pipeline geral está em [docs/REQUEST_FLOW.md](docs/REQUEST_FLOW.md).

O contrato e as regras da `NormalizedRequest` estão em [docs/NORMALIZED_REQUEST.md](docs/NORMALIZED_REQUEST.md).

### MCP

Os servidores MCP fornecem capacidades consultivas aos agentes.

A primeira versão prevê dois MCPs:

1. **Function Catalog MCP** — pesquisa funções, scripts e aplicações reutilizáveis.
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
   +-- Schema Validator
   +-- Telemetry
   |
   | HTTP sobre Unix Socket
   v
/run/ai-bash-gen/internal/llama.sock
   |
   v
llama-server
   |
   +-- MCP: function-catalog
   +-- MCP: google-mail
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
        +--> reutiliza capability existente
        |
        +--> ou gera nova capability parametrizada
        |
        v
validação
        |
        +--> capability nova válida retorna ao catálogo
        |
        v
script Bash
```

A aplicação transforma a solicitação em uma representação técnica curta em inglês, pesquisa capacidades reutilizáveis e usa o gerador para escolher uma existente ou produzir uma nova função parametrizada.

## Catálogo de funções

O Function Catalog armazenará funções reutilizáveis, incluindo:

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
- implementar Function Catalog MCP;
- implementar Google Mail MCP;
- integrar `llama.cpp`;
- adicionar testes de segurança e integração.
