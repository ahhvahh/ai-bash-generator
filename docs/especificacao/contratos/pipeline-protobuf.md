# Contratos Protobuf do pipeline

![CTR](https://img.shields.io/badge/CTR-CTR--0001-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Definir o plano de controle estruturado que conecta normalização, busca, resolução, geração de capability, validação, publicação e materialização.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0002 — Protobuf e TextProto](../../adr/contratos/protobuf-e-textproto.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função](../../adr/execucao/binding-invocacao.md)
- [ADR-0012 — Efeitos](../../adr/seguranca/efeitos-capabilities.md)
- [CTR-0005 — ABI JSON de functions](function-json.md)

## Tipo

`Protobuf`.

Mensagens internas de controle usam Protobuf. Na fronteira com LLM, a representação continua sendo Protobuf Text Format (TextProto).

JSON UTF-8 não substitui Protobuf como plano de controle. JSON é o payload funcional entre as functions do artifact conforme CTR-0005.

## Famílias de mensagens

A arquitetura necessita representar, sem fixar neste documento nomes de campos ainda não refinados:

- solicitação do usuário;
- `NormalizedRequest` e tasks normalizadas;
- requisição e candidatos de busca;
- geração de FUNCTION para task não resolvida;
- conjunto de tasks resolvidas e versões pinadas;
- validação;
- publicação de capability;
- materialização do `BashArtifact`.

O schema físico deve permanecer coerente com essas responsabilidades quando for atualizado.

## Semântica de NormalizedTask

Cada task possui três partes normativas:

### Input lógico

Campos estruturados disponíveis para a execução.

Um campo pode conter:

- valor literal preservado da solicitação;
- referência ao resultado de task anterior.

### Instruction

Texto objetivo que descreve a transformação desejada sem escolher implementação.

### Output contract

Estrutura esperada do resultado, incluindo objetos, listas e tipos escalares.

A representação física atual pode manter campos legados de descrição durante a transição, mas esses campos não mudam a semântica normativa acima.

## Dependências e DAG

`result_ref` representa dependência real de dados.

`depends_on` representa dependência exclusivamente de controle.

A ordem serializada das tasks deve ser estável, mas a execução é determinada pelo DAG:

- zero predecessores: task inicialmente pronta;
- predecessores concluídos: task pode tornar-se pronta;
- tasks independentes podem executar em paralelo;
- um output pode alimentar vários consumidores;
- uma task pode consumir múltiplos outputs.

Nenhuma dependência deve ser criada apenas para forçar uma lista linear.

## Resultado final

`final_output_ref` identifica o resultado solicitado ao cliente.

Quando houver transformação funcional para consolidar vários resultados, ela deve aparecer como task real. Quando houver apenas montagem estrutural de inputs, o Input Binder realiza o trabalho como infraestrutura.

## Controle versus dados

Protobuf carrega metadados, contratos, identidades, dependências e decisões de pipeline.

Durante execução do artifact, as functions trocam objetos JSON UTF-8 por stdin/stdout. Esses objetos devem ser compatíveis com os contratos lógicos definidos no plano de controle.

## Erros

Erros de controle devem ser estruturados e correlacionáveis. Erros das functions seguem CTR-0005. O envelope externo do daemon pertence ao CTR-0004.

## Regras e restrições

- parsing estrutural deve ser seguido por validação semântica;
- `request_id` interno é criado pela aplicação;
- o normalizador não escolhe encoding da implementation;
- capability existente somente é reutilizada com igualdade exata de input, propósito e output;
- capability existente usada precisa carregar o mesmo `capability_version_id` retornado pela busca;
- conjunto resolvido deve permitir reconstruir deterministicamente o DAG e o artifact;
- alterações incompatíveis no schema exigem estratégia de versão.

## BLOCKED

A definição física final do schema ainda depende da revisão do Protobuf para representar explicitamente os contratos lógicos sem duplicação desnecessária e das demais dependências ainda não refinadas.

## Critérios de aceite

- toda mensagem necessária ao pipeline possui responsabilidade inequívoca;
- input, instruction e output contract são preservados até a resolução;
- dependências de dados não são confundidas com sequência;
- tasks independentes permanecem independentes;
- Protobuf não é usado como payload funcional entre functions;
- JSON funcional não substitui o plano de controle Protobuf.
