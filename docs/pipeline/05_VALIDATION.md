# 05 — validation

## Responsabilidade

Esta etapa recebe o `GenerationResult` produzido pelo `bash-generator` e decide se o resultado pode seguir para materialização.

Não utiliza LLM.

## Entrada

```proto
message ValidationRequest {
  GenerationResult generation = 1;
}
```

## Validações

A aplicação deve verificar, no mínimo:

1. status da geração;
2. referências `result_ref`;
3. existência das capabilities utilizadas;
4. compatibilidade entre entrada e saída das chamadas;
5. argumentos obrigatórios;
6. dependências permitidas;
7. sintaxe Bash;
8. políticas de segurança;
9. novas capabilities geradas;
10. duplicidade de novas capabilities.

### Bash

A primeira validação sintática pode usar:

```text
bash -n
```

A validação deve ocorrer de forma controlada. O script não deve ser executado.

### Capabilities existentes

Toda capability usada deve ter sido obtida por `get_capability`.

O gerador não pode inventar implementação, parâmetros ou contratos de uma capability apenas a partir do resultado resumido de `search_capabilities`.

### Capabilities novas

Uma nova capability deve ser:

- genérica;
- parametrizada;
- independente dos valores concretos da solicitação;
- compatível com seu contrato de entrada;
- compatível com seu contrato de saída;
- deduplicada contra o catálogo;
- aprovada pelas políticas de segurança.

## Saída

```proto
message ValidationIssue {
  string code = 1;
  string message = 2;
}

message ValidationResult {
  bool valid = 1;
  GenerationResult generation = 2;
  repeated ValidationIssue issues = 3;
}
```

Exemplo:

```textproto
valid: true

generation {
  status: GENERATION_STATUS_READY
  final_output_ref: "sortedList"
}
```

Resultado inválido:

```textproto
valid: false

issues {
  code: "RESULT_REF_NOT_FOUND"
  message: "filteredList references an unknown previous result."
}
```

## Falha

Se `valid = false`, o arquivo Bash não deve ser criado.

A aplicação pode devolver os erros ou, quando configurado, realizar no máximo uma tentativa de correção pelo `bash-generator`.
