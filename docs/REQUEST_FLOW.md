# Fluxo de Requisição

Este documento descreve como o `ai-bash-gen` transforma uma solicitação escrita pelo usuário em uma instrução técnica estável antes de consultar MCPs e gerar um script Bash.

## Objetivo

A aplicação não deve enviar diretamente a frase original do usuário ao agente responsável por descobrir funções, scripts ou aplicações.

Primeiro, um LLM pequeno e barato deve normalizar a requisição.

A saída dessa etapa usa inglês como linguagem canônica interna.

## Exemplo

Solicitação:

```text
preciso listar as pastas que estão dentro da pasta ~/ambiente
```

Saída normalizada:

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

## Pipeline

```text
UserRequest
    |
    v
request-normalizer
    |
    v
NormalizedRequest
    |
    v
capability-discovery
    |
    +--> MCP capability-catalog
    |
    v
CapabilitySelection
    |
    v
bash-generator
    |
    v
ScriptArtifact
```

## 1. request-normalizer

Este agente deve utilizar um modelo pequeno.

Responsabilidades:

- compreender a frase original;
- remover linguagem desnecessária;
- manter valores concretos fornecidos pelo usuário;
- identificar entradas;
- identificar processamento;
- identificar saída;
- criar uma instrução curta em inglês;
- criar uma intenção estável.

Não deve:

- gerar código Bash;
- consultar MCP;
- executar comandos;
- completar requisitos ausentes por conta própria.

## 2. NormalizedRequest

Contrato inicial:

```json
{
  "canonical_instruction": "string",
  "intent": "string",
  "input": [],
  "processing": [],
  "output": []
}
```

### canonical_instruction

Frase curta e objetiva em inglês.

Exemplos:

```text
List subdirectories in ~/ambiente.
Compress /data into a gzip archive.
Find files larger than 100 MB in /var/log.
Read the latest invoice email from the configured mailbox.
```

### intent

Identificador técnico curto.

Exemplos:

```text
list_subdirectories
compress_directory
find_large_files
read_latest_invoice_email
```

## 3. capability-discovery

Recebe a `NormalizedRequest`.

Este agente pode consultar MCPs autorizados.

Sua função não é gerar o script final.

Ele deve localizar capacidades compatíveis e entregar uma lista estruturada ao gerador.

Exemplo:

```json
{
  "selected_capabilities": [
    {
      "id": "list-subdirectories",
      "version": 1,
      "reason": "Matches list_subdirectories intent and path input."
    }
  ]
}
```

## 4. bash-generator

Recebe:

- NormalizedRequest;
- capacidades selecionadas;
- informações retornadas por outros MCPs quando necessárias.

Responsabilidades:

- combinar capacidades;
- gerar o script Bash;
- declarar capacidades efetivamente utilizadas;
- produzir `ScriptArtifact`.

## Separação de responsabilidades

```text
request-normalizer
    understands language

capability-discovery
    finds reusable capabilities

MCP
    exposes structured knowledge/tools

bash-generator
    produces the final script

ai-bash-gen
    validates, controls and records telemetry
```

Essa separação permite trocar modelos individualmente e utilizar um modelo muito pequeno na normalização inicial.
