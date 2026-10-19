# Orquestração e autorização de MCPs pela aplicação

![ADR](https://img.shields.io/badge/ADR-ADR--0005-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

O gerador pode necessitar de detalhes de capabilities e dados de MCPs durante a geração.

## Problema

Acesso direto do modelo às integrações removeria controle central de autorização, limites e auditoria.

## Restrições

- Cada agente possui allowlist.
- Respostas externas são dados não confiáveis.
- MCP não executa script gerado.
- Ferramentas destrutivas não fazem parte da primeira versão.

## Opções consideradas

### LLM acessa MCP diretamente

Menor intermediação, porém sem autoridade central da aplicação.

### llama-server controla tools

Mistura inferência com autorização.

### Tool/MCP Orchestrator

A aplicação valida, autoriza, limita e audita todas as chamadas.

## Decisão

Todas as chamadas de `get_capability` e MCPs generation-time passam pelo Tool/MCP Orchestrator do `ai-bash-gen`.

## Justificativa

Mantém allowlist, schema, timeout, auditoria e políticas fora do modelo.

## Consequências

Generation-time tool e runtime capability permanecem conceitos distintos.

## Dependências

- [ADR-0001](../pipeline/pipeline-hibrido.md)

## Critérios de validação

- Tool não autorizada é rejeitada.
- Toda chamada possui limites e timeout aplicáveis.
- O modelo não acessa credenciais diretamente.
