# Contratos Protobuf do pipeline

![CTR](https://img.shields.io/badge/CTR-CTR--0001-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Definir a família de mensagens que conecta normalização, busca, geração, validação, publicação e materialização.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0002 — Protobuf e TextProto](../../adr/contratos/protobuf-e-textproto.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding de invocação](../../adr/execucao/binding-invocacao.md)
- [ADR-0012 — Efeitos](../../adr/seguranca/efeitos-capabilities.md)

## Tipo

`Protobuf`.

Mensagens internas usam Protobuf. Na fronteira com o LLM, a representação atual é Protobuf Text Format (TextProto).

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
- `GeneratorToolRequests` ou plano final na arquitetura-alvo;
- `GeneratorToolResponse`;
- `ValidationResult`;
- resultado de publicação;
- `BashArtifact`.

## Semântica de NormalizedRequest

### Ordem das tasks

`NormalizedRequest.tasks` é um campo `repeated` ordenado. A ordem emitida é a sequência canônica de processamento e deve ser preservada.

Não é necessário acrescentar uma dependência apenas para representar ordem. Dependências de dados e controle continuam explícitas.

### Dependência de dados

`result_ref` representa consumo real de um output anterior.

Um output pode possuir zero, um ou vários consumidores. Portanto:

- zero consumidores é válido para resultados independentes ou diretamente solicitados;
- um consumidor representa encadeamento simples;
- vários consumidores representam fan-out;
- uma task pode consumir múltiplos outputs anteriores, representando fan-in.

O normalizador não deve duplicar o conteúdo de um output para criar uma nova entrada.

### Dependência de controle

`depends_on` existe apenas quando uma task precisa aguardar outra por motivo de controle e não consome seu output.

### Resultado final

`final_output_ref` aponta para o output final solicitado. Quando a solicitação exige vários resultados finais, uma task de agregação lógica deve produzir um único objeto final.

## Definições de entrada e saída em JSON

O schema atual mantém `input_description` e `output_description` como `string`. Enquanto esses campos não forem substituídos por um contrato estrutural próprio, seu conteúdo deve ser um **objeto JSON válido**, compacto e determinístico, nunca prosa livre.

Exemplo conceitual:

```json
{
  "path": {
    "type": "path",
    "required": true
  }
}
```

No TextProto esse JSON é serializado dentro da string, com o escaping necessário.

`TaskInput.contract` e `TaskOutput.contract` continuam sendo a definição tipada usada pelo Protobuf e devem ser coerentes com o objeto JSON correspondente.

## Erros

Erros internos devem ser estruturados e correlacionáveis. O envelope externo do daemon pertence ao [CTR-0004](api-daemon.md).

## Regras e restrições

- Parsing estrutural deve ser seguido por validação semântica.
- `request_id` interno é criado pela aplicação.
- `result_ref` representa dependência de dados.
- `depends_on` representa dependência de controle.
- A ordem de `tasks` representa a sequência lógica.
- O plano não deve inventar dados ausentes.
- Capability existente usada pelo plano precisa apontar para versão resolvida.

## Compatibilidade

O schema canônico permanece em `proto/ai_bash_gen/v1/pipeline.proto`.

A semântica de sequência definida aqui utiliza a ordem já preservada pelo campo `repeated tasks` e, portanto, não exige um novo campo `sequence` no Protobuf.

A exigência de JSON em `input_description` e `output_description` também não altera wire format porque os campos permanecem `string`.

## Critérios de aceite

- Toda mensagem necessária ao pipeline tem entrada, saída e erro determináveis.
- A ordem das tasks é preservada.
- Dependências de dados não são confundidas com sequência ou dependências de controle.
- Outputs com zero, um ou vários consumidores são válidos.
- Definições de entrada e saída em strings contêm JSON válido.
- Alterações incompatíveis futuras são acompanhadas por estratégia de versão.
