# Configuração de agentes

![CTR](https://img.shields.io/badge/CTR-CTR--0003-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Definir a configuração reutilizável e o ciclo administrativo de um agente sobre o motor de inferência.

## Dependências

- [ADR-0014 — Lifecycle de modelos](../../adr/runtime/lifecycle-modelos.md)
- [CTR-0002 — MCP](mcp.md)

## Tipo

`configuração | interface`

## Operações administrativas

A interface prevista inclui:

- `agent create`;
- `agent list`;
- `agent show <id>`;
- `agent validate <id>`;
- `agent edit <id>`;
- `agent disable <id>`;
- `agent enable <id>`;
- `agent remove <id>`.

Remoção exige confirmação explícita e preservação de backup da configuração anterior.

## Entrada

Campos conceituais:

- versão do schema;
- `id`, nome e descrição;
- enabled;
- modelo GGUF e arquivo;
- parâmetros de geração;
- perfil do llama;
- timeout e máximo de tool calls;
- tipo/schema de entrada e saída;
- MCPs permitidos;
- referência para prompt canônico.

IDs seguem `[a-z0-9][a-z0-9-]{1,62}`.

## Persistência da configuração

Diretório padrão documentado:

`/etc/ai-bash-gen/agents/`

Cada agente utiliza um arquivo YAML próprio. O diretório de modelos documentado é:

`/var/lib/ai-bash-gen/models/`

Arquivos devem possuir acesso administrativo restrito. A gravação segue:

1. gerar conteúdo;
2. validar;
3. gravar temporário;
4. fsync;
5. ajustar permissões;
6. rename atômico.

## Modelo GGUF

Antes da ativação, validar:

- arquivo existente e regular;
- extensão `.gguf`;
- leitura pelo usuário do serviço;
- tamanho maior que zero;
- localização em diretório autorizado;
- SHA-256 quando configurado;
- reconhecimento pelo runtime de inferência.

O serviço não baixa modelos automaticamente durante operação normal.

## Perfis de inferência

Perfis previstos: `cpu`, `gpu` e `auto`.

O perfil CPU de referência documentado usa:

- context size: 4096;
- threads: 2;
- threads batch: 2;
- device: none;
- GPU layers: 0;
- batch size: 512;
- ubatch size: 128;
- flash attention: auto.

No perfil GPU, a configuração prevê seleção do dispositivo, GPU layers automáticas, fit, target de memória, GPU principal e split mode.

No perfil `auto`, a aplicação detecta dispositivos suportados pelo runtime, prefere GPU compatível e retorna a CPU quando necessário.

O perfil efetivo deve ser visível em diagnóstico.

## Saída

Configuração validada e carregável pelo daemon, com perfil configurado e perfil efetivo.

## Erros

- ID inválido ou duplicado;
- modelo inexistente, vazio, ilegível ou fora do diretório autorizado;
- schema desconhecido;
- MCP não cadastrado;
- parâmetro fora do intervalo;
- prompt ausente;
- perfil de hardware incompatível;
- falha de reload.

## Regras e restrições

- Alteração exige validação completa antes do reload.
- Falha de reload mantém a configuração ativa anterior.
- Argumentos livres não podem sobrescrever controles de segurança do serviço.
- O valor efetivo de limites é o mais restritivo entre configuração global e do agente.
- Prompts canônicos são referenciados, não duplicados.
- MCPs são explicitamente permitidos por agente.

**BLOCKED:** a relação entre agentes e modelos não pode ser fechada antes do ADR-0014.

## Compatibilidade

O schema do YAML deve possuir versão. Alterações incompatíveis precisam de estratégia explícita de migração.

## Critérios de aceite

- Validação ocorre antes da ativação ou reload.
- Configuração parcial nunca substitui configuração válida.
- MCP permitido é explícito.
- Modelo e perfil efetivos ficam observáveis em diagnóstico.
- O arquivo de configuração é substituído atomicamente.
