# Informação obrigatória ausente

![FLW](https://img.shields.io/badge/FLW-FLW--0003-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Interromper cedo o pipeline quando a solicitação não contém informação essencial, sem inventar valores.

## Dependências

- [MOD-0001 — Request Normalizer](../modulos/request-normalizer.md)
- [CTR-0001 — Protobuf](../contratos/pipeline-protobuf.md)

## Gatilho

O normalizador identifica pelo menos uma entrada obrigatória ausente.

## Pré-condições

- solicitação recebida;
- normalização executada.

## Fluxo principal

1. O normalizador retorna status `MISSING_INFORMATION`.
2. Cada lacuna identifica tarefa, nome, descrição e contrato aplicável.
3. A aplicação valida a consistência das lacunas.
4. O Pipeline Manager encerra o processamento da geração.
5. Capability Search e Capability Function Generator não são chamados.
6. O cliente recebe a informação necessária conforme o contrato externo.

## Fluxos alternativos

### Requisição completa

Se o status for READY e não houver `missing_inputs`, o pipeline continua.

### Requisição não suportada

Status UNSUPPORTED encerra o pipeline com erro/resultado correspondente.

## Falhas e tratamento

Status READY com `missing_inputs` é inválido.

## Resultado

Pedido estruturado de informação adicional, sem efeitos posteriores no pipeline.

## Critérios de aceite

- Nenhuma capability é pesquisada.
- Nenhuma tool é chamada.
- Nenhum valor ausente é inventado.
- A lacuna é vinculada à tarefa afetada.
