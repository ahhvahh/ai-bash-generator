# Protobuf entre componentes e TextProto na fronteira LLM

![ADR](https://img.shields.io/badge/ADR-ADR--0002-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

O pipeline precisa de contratos estruturados e de representação textual para o modelo.

## Problema

Protobuf binário não é apropriado para interação textual do LLM; texto livre não oferece contrato suficiente.

## Restrições

- O mesmo schema deve orientar comunicação interna e fronteira LLM.
- Saída do LLM deve ser parseada e validada.
- Economia de tokens de TextProto não é presumida.

## Opções consideradas

### JSON em todas as fronteiras

Criaria representação paralela ao schema Protobuf.

### Protobuf binário inclusive no LLM

Inadequado para interação textual.

### Protobuf interno e TextProto no LLM

Usa o mesmo schema com representações distintas.

## Decisão

Usar Protobuf binário entre componentes e Protobuf Text Format na fronteira com o LLM.

## Justificativa

Mantém uma fonte de schema e parsing determinístico.

## Consequências

TextProto precisa de benchmark contra JSON compacto; parsing não substitui validação semântica ou autorização.

## Dependências

- [ADR-0001](../pipeline/pipeline-hibrido.md)

## Critérios de validação

- IPC interno usa Protobuf.
- O LLM recebe e devolve texto parseável pelo schema.
- Não há Protobuf binário em Base64 enviado ao modelo.
