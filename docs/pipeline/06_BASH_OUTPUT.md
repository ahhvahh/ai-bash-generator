# 06 — bash-output

## Responsabilidade

Esta é a última etapa do pipeline.

Ela recebe uma geração já validada e produz o arquivo Bash entregue ao cliente.

Não utiliza LLM.

## Entrada

```proto
message BashOutputRequest {
  ValidationResult validation = 1;
  string requested_filename = 2;
}
```

A etapa só aceita:

```text
validation.valid = true
```

## Processamento

A aplicação deve:

1. obter o script validado;
2. garantir shebang apropriado;
3. normalizar final de linha;
4. definir nome seguro para o arquivo;
5. calcular checksum;
6. persistir novas capabilities aprovadas;
7. criar o artefato Bash;
8. devolver o conteúdo ou gravar no destino autorizado.

## Capability reutilizável

Quando o `bash-generator` produzir uma nova função, existem dois resultados distintos:

```text
capability genérica
        +
invocação específica da requisição
        =
arquivo Bash final
```

Exemplo:

```bash
list_directory_details() {
    local path="$1"
    # implementação reutilizável
}

list_directory_details "$HOME/ambiente"
```

A função genérica pode ser persistida no catálogo após a validação.

O valor `$HOME/ambiente` pertence somente à invocação atual.

## Saída

```proto
message BashArtifact {
  string filename = 1;
  string content = 2;
  string sha256 = 3;
  string final_output_ref = 4;
}
```

Exemplo:

```textproto
filename: "list-executable-files.sh"
content: "#!/usr/bin/env bash\n..."
sha256: "..."
final_output_ref: "sortedList"
```

## Escrita em disco

Quando a aplicação gravar o arquivo:

```text
gerar temporário
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

O arquivo não deve ser executado automaticamente.

## Permissões

Permissão inicial sugerida para arquivos gerados:

```text
0640
```

A decisão de tornar o script executável deve ser explícita e separada da geração.
