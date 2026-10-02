# Configuração de agentes

![CTR](https://img.shields.io/badge/CTR-CTR--0003-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Definir a configuração reutilizável de um agente sobre o motor de inferência.

## Dependências

- [ADR-0014 — Lifecycle de modelos](../../adr/runtime/lifecycle-modelos.md)
- [CTR-0002 — MCP](mcp.md)

## Tipo

`configuração | interface`

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

IDs seguem o padrão documentado `[a-z0-9][a-z0-9-]{1,62}`.

## Saída

Configuração validada e carregável pelo daemon, com perfil configurado e perfil efetivo quando aplicável.

## Erros

- ID inválido ou duplicado;
- modelo inexistente, vazio, ilegível ou fora do diretório autorizado;
- schema desconhecido;
- MCP não cadastrado;
- parâmetro fora do intervalo;
- prompt ausente;
- perfil de hardware incompatível.

## Regras e restrições

- Configurações são armazenadas como YAML em diretório administrativo.
- Gravação de configuração é atômica.
- Alteração exige validação completa antes do reload.
- Falha de reload mantém configuração ativa anterior.
- O programa não deve permitir argumentos livres que sobrescrevam controles de segurança.
- Arquivo GGUF não é baixado automaticamente durante operação normal.
- CPU, GPU e auto são perfis previstos; detecção usa dispositivos reportados pelo runtime de inferência.
- O valor efetivo de limites é o mais restritivo entre global e agente.

**BLOCKED:** a relação entre agentes e modelos não pode ser fechada antes do ADR-0014.

## Compatibilidade

Os prompts canônicos ficam em documentos próprios e não devem ser duplicados na configuração.

## Critérios de aceite

- Validação ocorre antes da ativação ou reload.
- Configuração parcial nunca substitui configuração válida.
- MCP permitido é explícito.
- Modelo e perfil efetivos ficam observáveis em diagnóstico.
