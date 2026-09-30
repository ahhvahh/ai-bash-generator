# 06 — bash-output

## Responsabilidade

Materializar deterministicamente o arquivo Bash a partir de um `ValidationResult` válido.

Não utiliza LLM.

Publicação de capability e gravação de arquivo são operações independentes.

## Entrada

```proto
message BashOutputRequest {
  ValidationResult validation = 1;
  string requested_filename = 2;
}
```

Somente aceita:

```text
validation.valid = true
```

## Montagem determinística

O arquivo é derivado de:

- `GenerationPlan.calls`;
- versões resolvidas;
- novas capabilities validadas;
- bindings literais;
- `stdin_result_ref`;
- `final_output_ref`.

Não existe script livre produzido pelo LLM.

## Pipelines

Para streams:

```bash
producer ... |
consumer ... |
final_stage ...
```

O assembler deve incluir:

```bash
set -euo pipefail
```

`stdout` é dado funcional e `stderr` é diagnóstico.

## Valores shell

Valores literais são tratados como dados.

O materializador é responsável por quoting e representação shell.

Exemplo semântico:

```text
~/ambiente
```

pode ser materializado de forma segura como:

```bash
"$HOME/ambiente"
```

Não se deve gerar:

```bash
"~/ambiente"
```

quando expansão de home for necessária.

## Publicação de novas capabilities

O Bash Output não grava diretamente o catálogo.

Após validação, o Pipeline pode executar em paralelo:

```text
Capability Publisher
Bash Output
```

Publisher:

```proto
message CapabilityPublishRequest {
  string request_id = 1;
  string idempotency_key = 2;
  GeneratedCapability capability = 3;
}
```

A operação é idempotente e protegida por fingerprint única.

Falha de publicação não corrompe o arquivo já materializado; falha de filesystem não desfaz uma publicação válida.

## Arquivo

Processo:

```text
gerar conteúdo em memória
      |
      v
calcular sha256
      |
      v
gravar temporário
      |
      v
fsync
      |
      v
chmod
      |
      v
rename atômico
```

Permissão inicial:

```text
0640
```

Tornar executável é uma operação explícita posterior.

## Saída

```proto
message BashArtifact {
  string filename = 1;
  string content = 2;
  string sha256 = 3;
  string final_output_ref = 4;
}
```

O arquivo não é executado automaticamente.
