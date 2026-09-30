# 05 — validation

## Responsabilidade

Recebe o `GenerationPlan` e todas as versões de capabilities resolvidas.

Não utiliza LLM.

## Entrada

```proto
message ValidationRequest {
  GenerationPlan plan = 1;
  repeated CapabilityDefinition resolved_capabilities = 2;
}
```

## Ordem de validação

```text
protobuf validation
      |
      v
graph validation
      |
      v
contract validation
      |
      v
capability version validation
      |
      v
policy validation
      |
      v
deterministic Bash assembly preview
      |
      v
bash -n
      |
      v
ShellCheck
      |
      v
dependency validation
```

O script nunca é executado.

## Grafo

Validar:

- resultados únicos;
- `result_ref` existente;
- dependências de controle;
- ciclos;
- um único stream estruturado por stdin;
- restrições de fan-out/fan-in.

## Contratos

Validar:

- `DataKind`;
- campos obrigatórios;
- `StreamEncoding`;
- scalar x stream;
- argumentos obrigatórios;
- stdout da produtora compatível com stdin da consumidora.

## Versions

Toda capability existente usada no plano deve possuir:

```text
capability_version_id
version
checksum
```

e deve estar presente em `resolved_capabilities`.

## Segurança

Rejeitar conforme política:

- `eval` quando não explicitamente permitido;
- escrita destrutiva não autorizada;
- comandos não permitidos;
- dependências não declaradas;
- caminhos fora de escopo quando aplicável;
- uso de rede fora das capabilities autorizadas.

## Bash

O assembler cria uma prévia deterministicamente a partir do plano.

Executar:

```text
bash -n
ShellCheck
```

`ShellCheck` deve fazer parte da instalação de validação da primeira versão. Se estiver indisponível por falha de ambiente, a validação deve falhar de forma explícita em vez de ser silenciosamente ignorada.

## Saída

```proto
message ValidationResult {
  bool valid = 1;
  GenerationPlan plan = 2;
  repeated CapabilityDefinition resolved_capabilities = 3;
  repeated ValidationIssue issues = 4;
}
```

## Correção

Por política, pode existir no máximo uma nova tentativa do `bash-generator` usando a lista estruturada de `ValidationIssue`.

Se a segunda validação falhar, não criar o arquivo.
