# Prompt canônico do Request Normalizer

**ID:** PRM-0001  
**Status:** refinement

## Dependências

- [MOD-0001 — Request Normalizer](../modulos/request-normalizer.md)
- [CTR-0001 — Contratos Protobuf do pipeline](../contratos/pipeline-protobuf.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Objetivo

Converter uma solicitação humana em uma `NormalizedRequest` composta por tasks independentes de implementação.

A fronteira com o LLM continua usando TextProto. O normalizador descreve contratos lógicos; não escolhe JSON, stdin/stdout, comandos, applications, scripts, services ou capabilities.

## Semântica obrigatória de cada task

Cada task deve conter conceitualmente:

1. **input** — campos estruturados disponíveis, preservando valores literais e referências a resultados anteriores;
2. **instruction** — descrição objetiva do processamento necessário;
3. **output contract** — estrutura tipada esperada do resultado.

A representação física atual pode utilizar os campos existentes do Protobuf durante a transição. Quando contratos ainda estiverem transportados em strings, seu conteúdo deve continuar sendo JSON válido e determinístico, mas isso é compatibilidade de wire format, não escolha de encoding de execução.

## DAG

`result_ref` existe apenas para dependência real de dados.

`depends_on` existe apenas para dependência de controle sem transporte de dados.

A ordem das tasks deve ser estável e respeitar precedência, porém tasks independentes não devem receber dependências artificiais. O runtime pode executá-las em paralelo.

Fan-out é permitido pela reutilização da mesma referência.

Fan-in é representado por múltiplos campos de input apontando para resultados predecessores. O normalizador não cria uma task de merge quando a necessidade é apenas montagem estrutural do objeto de entrada.

## Regras canônicas

O agente deve:

- escrever instruction e descrições semânticas em inglês;
- preservar valores literais exatamente como fornecidos;
- dividir a solicitação em tasks pequenas e semanticamente independentes;
- manter IDs únicos em `snake_case`;
- definir input, instruction e output contract para cada task;
- não criar dependências apenas para produzir sequência linear;
- não escolher Bash commands, programs, capabilities, packages, databases ou tools;
- não gerar Bash;
- não executar ações;
- não inventar valores ausentes;
- retornar `MISSING_INFORMATION` quando uma entrada obrigatória não puder ser determinada;
- definir `final_output_ref` para o resultado solicitado ao usuário.

## Compatibilidade com o runtime atual

A implementação atual ainda utiliza o schema e prompt anteriores. Este documento descreve a arquitetura-alvo e permanece em `refinement` até o contrato físico e a implementação serem reconciliados.

## Critérios de aceite

- a saída contém somente TextProto de `NormalizedRequest`;
- cada task possui input lógico, instruction e output contract determináveis;
- tasks independentes permanecem independentes;
- `result_ref` aponta somente para outputs anteriores existentes;
- fan-in estrutural não cria transformação artificial;
- nenhum detalhe da ABI JSON aparece como escolha do normalizador;
- `final_output_ref` aponta para o resultado final solicitado.
