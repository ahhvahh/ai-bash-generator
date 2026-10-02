# Bash Output

![MOD](https://img.shields.io/badge/MOD-MOD--0005-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Materializar deterministicamente o arquivo Bash a partir de um `ValidationResult` válido.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0003 — ABI](../../adr/execucao/abi-stdout-stdin.md)
- [ADR-0006 — Publicação e materialização](../../adr/pipeline/publicacao-materializacao.md)
- [ADR-0010 — Binding de invocação](../../adr/execucao/binding-invocacao.md)
- [CTR-0001 — Protobuf](../contratos/pipeline-protobuf.md)

## Responsabilidades

- montar o script a partir do plano e definições validadas;
- fazer quoting e representação shell de valores;
- conectar streams conforme ABI;
- calcular SHA-256 do artifact;
- gravar de forma atômica;
- não executar o artifact.

## Entradas

`BashOutputRequest` com validação válida e nome solicitado.

## Saídas

`BashArtifact` contendo nome, conteúdo, checksum e referência de saída final.

## Restrições

- Aceita somente `validation.valid = true`.
- O script inclui `set -euo pipefail`.
- Permissão inicial documentada: `0640`; tornar executável é operação posterior.
- Valores literais são dados, não fragmentos shell.
- Publicação no catálogo não é responsabilidade do Bash Output.

**BLOCKED:** binding de invocação ainda está em refinamento. Regras finais de filename, manifesto de dependências e portabilidade também permanecem pendentes.

## Critérios de aceite

- Conteúdo deriva apenas do plano validado.
- Gravação usa temporário, fsync e rename atômico.
- O artifact não é executado automaticamente.
- Falha de filesystem não altera o resultado de uma publicação independente.

## Implementação relacionada

Referência histórica: materializador de saída; não verificado nesta adequação.
