# Contratos Protobuf do pipeline

## Objetivo

O Protobuf é o contrato canônico de dados do pipeline.

Schema principal:

```text
../../proto/ai_bash_gen/v1/pipeline.proto
```

## Regra principal

Existem duas representações:

```text
entre componentes
    Protobuf binário

entre ai-bash-gen e LLM
    Protobuf Text Format
```

O LLM não recebe bytes Protobuf diretamente.

Também não usar:

```text
binary protobuf
      |
      v
base64
      |
      v
prompt
```

Base64 aumenta o conteúdo textual e remove significado legível para o modelo.

## Entrada do LLM

O `ai-bash-gen` recebe ou constrói uma mensagem Protobuf e cria uma visão mínima para a etapa atual.

Exemplo em Go, conceitualmente:

```go
text, err := prototext.MarshalOptions{
    Multiline: true,
}.Marshal(message)
```

Somente campos necessários à etapa devem ser incluídos.

## Saída do LLM

O prompt exige somente TextProto compatível com a mensagem esperada.

A aplicação converte:

```text
LLM text
   |
   v
prototext.Unmarshal
   |
   v
protobuf message
   |
   v
semantic validation
```

Uma resposta que não possa ser convertida para a mensagem esperada é inválida.

## Economia de tokens

Protobuf binário reduz tamanho no IPC e armazenamento, mas não reduz diretamente tokens do LLM.

Para reduzir tokens do modelo:

1. enviar somente a mensagem necessária à etapa;
2. omitir campos padrão;
3. limitar candidatos;
4. usar nomes de campos curtos, mas semanticamente claros;
5. não repetir conteúdo já referenciado por `result_ref`;
6. não enviar código durante `search_capabilities`;
7. recuperar detalhes somente por `get_capability`;
8. não enviar telemetria ao modelo;
9. não enviar metadados internos como timestamps ou IDs de banco.

## Envelopes internos

Metadados operacionais como:

```text
request_id
pipeline_id
timestamps
trace_id
```

devem permanecer no envelope interno da aplicação quando o LLM não precisar deles.

Isso evita gastar contexto com informações sem valor semântico para a inferência.

## Protobuf Text Format

Exemplo:

```textproto
tasks {
  id: "filter_executables"
  instruction: "Keep executable files only."

  inputs {
    name: "source"
    type: "table"
    result_ref: "resultList"
  }

  output {
    name: "filteredList"
    type: "table"
  }
}
```

Comparado a transportar novamente todos os itens de `resultList`, a referência custa poucos tokens e mantém o grafo de dados explícito.

## Segurança

TextProto produzido pelo LLM continua sendo conteúdo não confiável.

Depois de `prototext.Unmarshal`, a aplicação deve executar validação semântica antes de:

- consultar MCPs;
- montar scripts;
- persistir capabilities;
- acessar serviços externos.

Protobuf garante estrutura. Não garante que o conteúdo seja correto ou autorizado.
