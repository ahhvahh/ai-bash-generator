# Contratos Protobuf do pipeline

![CTR](https://img.shields.io/badge/CTR-CTR--0001-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Definir a família de mensagens que conecta normalização, busca, geração, tools, validação, publicação e materialização.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0002 — Protobuf e TextProto](../../adr/contratos/protobuf-e-textproto.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding de invocação](../../adr/execucao/binding-invocacao.md)
- [ADR-0012 — Efeitos](../../adr/seguranca/efeitos-capabilities.md)

## Tipo

`Protobuf`

## Entrada

Famílias documentadas:

- `UserRequest`;
- `NormalizedRequest` e `NormalizedTask`;
- `SearchCapabilitiesRequest` e orçamento;
- `GeneratorTurnRequest` e respostas de tools;
- `GenerationPlan`;
- `ValidationRequest`;
- `CapabilityPublishRequest`;
- `BashOutputRequest`.

## Saída

Famílias documentadas:

- candidatos de busca;
- `GeneratorToolRequests` ou plano final;
- `GeneratorToolResponse`;
- `ValidationResult`;
- resultado de publicação;
- `BashArtifact`.

## Erros

Erros internos devem ser estruturados e correlacionáveis. O envelope externo do daemon pertence ao [CTR-0004](api-daemon.md).

## Regras e restrições

- Mensagens internas usam Protobuf binário.
- A visão do LLM usa TextProto.
- Parsing estrutural é seguido por validação semântica.
- `request_id` interno é criado pela aplicação.
- `result_ref` representa dependência de dados; `depends_on`, dependência de controle.
- O plano não contém script livre.
- Capability existente usada pelo plano precisa apontar para versão resolvida.

**BLOCKED:** o schema final depende dos ADRs 0008, 0009, 0010 e 0012.

## Compatibilidade

O schema canônico permanece referenciado em `proto/ai_bash_gen/v1/pipeline.proto`, mas esse arquivo não foi usado como fonte de validação nesta adequação.

## Critérios de aceite

- Toda mensagem necessária ao pipeline tem entrada, saída e erro determináveis.
- Não existem campos semanticamente duplicados para o mesmo dado.
- Tipos versionáveis não dependem de texto livre quando validação determinística for necessária.
- Alterações incompatíveis são acompanhadas por estratégia de versão funcional.
