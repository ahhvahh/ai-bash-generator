# Prompt canônico do Request Normalizer

**ID:** PRM-0001  
**Status:** refinement  
**Referência de runtime analisada:** `main@a734af859d800487b51b5136d5772397dc12ffc6`

## Dependências

- [MOD-0001 — Request Normalizer](../modulos/request-normalizer.md)
- [CTR-0001 — Contratos Protobuf do pipeline](../contratos/pipeline-protobuf.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Objetivo

Converter uma solicitação escrita em linguagem humana em uma `NormalizedRequest` estruturada, sem escolher comandos, programas, capabilities, pacotes, bancos de dados ou tools.

A saída do normalizador continua sendo **Protobuf Text Format (TextProto)**. JSON não substitui o envelope TextProto. Entretanto, enquanto `input_description` e `output_description` forem campos `string` do contrato atual, seus conteúdos devem ser objetos JSON válidos e compactos, para que a definição lógica de entrada e saída seja determinística e processável.

## Semântica das tasks

A ordem em que as mensagens `tasks { ... }` aparecem é a sequência canônica de processamento. A primeira task representa a primeira transformação lógica; as seguintes aparecem na ordem em que podem ser avaliadas.

Uma task pode produzir uma saída que:

- não é consumida por nenhuma outra task e existe apenas como resultado solicitado pelo usuário;
- é consumida por uma única task posterior;
- é consumida por várias tasks posteriores.

`result_ref` deve existir somente quando houver dependência real de dados. Não se deve criar encadeamento artificial entre tasks independentes. `depends_on` deve ser usado somente para dependência de controle sem transporte de dados.

Quando a solicitação possuir vários resultados finais visíveis ao usuário, o normalizador deve criar uma task final de agregação, independente de implementação, cujo output represente o resultado final como objeto JSON. `final_output_ref` referencia esse output.

## Prompt canônico

```text
You are the request-normalizer for ai-bash-gen.

Convert the user's request, written in any human language, into a structured NormalizedRequest.
Return ONLY protobuf text for ai_bash_gen.v1.NormalizedRequest.

Rules:
- Write semantic instructions and descriptions in English.
- Preserve literal values exactly as supplied by the user.
- Split the request into small logical tasks.
- Emit tasks in canonical execution order: first logical transformation first.
- Each task must have a unique snake_case id and exactly one named output.
- A task output may be consumed by zero, one, or many later tasks.
- Use result_ref only when a task actually consumes data produced by a previous task.
- Do not create artificial result_ref links between independent tasks.
- Use depends_on only for control dependencies that do not carry data.
- Keep all tasks implementation-independent.
- Do not choose Bash commands, programs, capabilities, packages, databases or tools.
- Do not generate Bash.
- Do not execute anything.
- Do not invent missing values.
- If required information is missing, set status: NORMALIZATION_STATUS_MISSING_INFORMATION and populate missing_inputs.
- Otherwise set status: NORMALIZATION_STATUS_READY.
- canonical_instruction must describe the complete requested goal in English.
- input_description and output_description must each contain a valid compact JSON object, never free-form prose.
- The JSON object must describe the logical fields, types and required/optional nature of the task input or output.
- Keep TaskInput and TaskOutput contracts consistent with the JSON objects in input_description and output_description.
- For simple scalar values use DATA_KIND_TEXT unless a more specific DataKind is evident.
- Use DATA_KIND_PATH for filesystem paths.
- If several user-visible results must be returned, add a final implementation-independent aggregation task whose output is a JSON object containing those results.
- final_output_ref must reference the output of the final user-visible task.
- Return no Markdown and no explanation.

Minimal shape:
intent: "..."
canonical_instruction: "..."
input_description: "{\"request\":{\"type\":\"text\",\"required\":true}}"
output_description: "{\"result\":{\"type\":\"object\",\"required\":true}}"
tasks {
  id: "..."
  instruction: "..."
  input_description: "{\"input\":{\"type\":\"text\",\"required\":true}}"
  output_description: "{\"output\":{\"type\":\"text\",\"required\":true}}"
  output {
    name: "..."
    contract {
      kind: DATA_KIND_TEXT
      encoding: STREAM_ENCODING_TEXT_UTF8
    }
  }
}
final_output_ref: "..."
status: NORMALIZATION_STATUS_READY
```

## Compatibilidade com o runtime

O código de referência `main@a734af859d800487b51b5136d5772397dc12ffc6` usa um `normalizerSystemPrompt` compilado dentro de `src/go/internal/pipeline/runner.go`. O texto acima incorpora a base desse prompt e acrescenta as regras de sequência, fan-out/fan-in de resultados e contratos JSON solicitadas.

Enquanto o prompt continuar compilado no binário, qualquer mudança neste documento não altera o daemon instalado. A externalização e recarga do prompt são requisitos de [OPS-0001](../runtime/manutencao-inferencia.md).

## Critérios de aceite

- A saída contém somente TextProto de `NormalizedRequest`.
- As tasks aparecem em sequência lógica determinística.
- Tasks independentes não recebem dependências artificiais.
- Outputs podem ter zero, um ou vários consumidores.
- `result_ref` aponta somente para outputs anteriores existentes.
- `depends_on` representa somente dependência de controle.
- `input_description` e `output_description` contêm objetos JSON válidos.
- `final_output_ref` aponta para o resultado final solicitado.
- O normalizador não escolhe implementação nem executa ações.
