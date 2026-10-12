# OPEN-003 — Contratos estruturados na interação com inferência

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais garantias de clareza, validade e interoperabilidade das solicitações são indispensáveis, independentemente do formato de contrato?

## Contexto para refinamento

A troca de informações entre etapas pode exigir conteúdo estruturado, validável e compreensível. Foram avaliadas representações distintas para comunicação entre componentes e para instruções de modelos de inferência. A escolha de codificação não altera, por si só, a necessidade do produto de preservar significado e integridade.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Que garantias de clareza, validação e integridade são exigidas das informações processadas?
- O produto exige interoperabilidade entre mecanismos de inferência diferentes?
- A comparação entre alternativas precisa ser baseada em testes de custo, qualidade e compatibilidade?

## Impacto

Define a necessidade de resultados interpretáveis e verificáveis sem fixar serialização no Charter.

## Bloqueadora

Não — formato e schema são decisões de Scope/Implementation.

## Próxima ação

Refinar o resultado verificável de interoperabilidade, sem transportar formatos físicos para Charter.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [CON-001](../constraints/CON-001.md)

## Candidatos de representação compacta — ilustração não normativa

**PROPOSED para experimentação:** testar JSON compacto com campos fixos e tuplas posicionais, reduzindo repetição para modelos menores. A escolha de codificação, schema, versão e limites de tamanho permanece pendente de Scope/Implementation.

- A planejadora em [OBJ-003](../objectives/OBJ-003.md) recebe solicitação original e retorna `status`, `tasks` e, se necessário, `questions`.
- Uma tarefa pode representar `id`, `goal`, `in`, `out`, `deps`, `rules`, `accept`, com entradas `[nome,tipo,valor]` e saídas `[nome,tipo]`.
- `@T1.files` pode indicar referência lógica entre tarefas; `file_size[]` representa um tipo lógico não serializado.
- A geradora em [OBJ-001](../objectives/OBJ-001.md) recebe uma tarefa de cada vez; a revisora em [OBJ-004](../objectives/OBJ-004.md) recebe solicitação, tarefa e candidata, retornando parecer.

```json
{
  "id": "T1",
  "goal": "Listar arquivos .log maiores que 10 MiB",
  "in": [
    [
      "dir",
      "path",
      "/var/log"
    ],
    [
      "min_mib",
      "int",
      10
    ]
  ],
  "out": [
    [
      "files",
      "file_size[]"
    ]
  ],
  "deps": [],
  "rules": [
    "somente leitura",
    "extensão .log"
  ],
  "accept": [
    "somente arquivos regulares",
    "tamanho > 10 MiB"
  ]
}
```

**PENDING —** definir representação física de coleções, referências, passagem de parâmetros e versão do contrato; comparar tokens, latência, precisão e compatibilidade entre modelos. Os critérios de igualdade exata de [OBJ-002](../objectives/OBJ-002.md) continuam independentes dos valores concretos.
