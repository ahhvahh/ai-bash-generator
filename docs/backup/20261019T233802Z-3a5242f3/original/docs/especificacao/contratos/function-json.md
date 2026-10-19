# ABI JSON de functions

![CTR](https://img.shields.io/badge/CTR-CTR--0005-9a6700?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Definir a interface funcional uniforme usada para compor capabilities dentro do artifact Bash.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0003 — ABI JSON por stdin/stdout](../../adr/execucao/abi-stdout-stdin.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função](../../adr/execucao/binding-invocacao.md)

## Tipo

`interface`

## Entrada

Cada function recebe pelo stdin exatamente um documento JSON UTF-8 cujo valor raiz é um objeto.

Os campos do objeto devem corresponder ao contrato lógico de input da task resolvida.

Valores podem incluir:

- objetos;
- listas;
- strings;
- números;
- booleanos;
- `null`.

Referências a resultados anteriores são resolvidas pelo pipeline antes da chamada da function. A function recebe valores, não `result_ref` não resolvidos.

## Saída

Em sucesso, stdout contém exatamente um documento JSON UTF-8 cujo valor raiz é um objeto compatível com o output contract da capability.

Logs, progresso e diagnósticos não podem ser escritos em stdout.

## Erros

- código de saída `0`: sucesso;
- código diferente de zero: falha;
- stderr: diagnóstico humano ou técnico da falha;
- stdout de uma execução com falha não deve ser tratado como resultado funcional válido.

A taxonomia específica de códigos de saída permanece pendente.

## Regras e restrições

- a ABI externa da function é igual para FUNCTION, SCRIPT, APPLICATION e SERVICE;
- wrappers podem adaptar JSON para argumentos, environment, arquivos ou protocolos internos;
- o assembler não conhece essa adaptação;
- o JSON não deve conter fragmentos shell destinados a interpolação;
- o contrato lógico determina quais campos são obrigatórios ou opcionais;
- o Input Binder pode montar um objeto a partir de múltiplos predecessores;
- montagem estrutural de inputs não cria capability;
- uma transformação semântica real deve continuar representada por uma task/capability.

## Fan-out e fan-in

Um resultado pode alimentar vários consumidores.

Uma task com múltiplos predecessores recebe um único objeto JSON montado deterministicamente a partir dos campos e `result_ref` definidos na task.

O mecanismo concreto usado pelo artifact para preservar resultados paralelos até o fan-in não é definido por este contrato.

## Compatibilidade

A ABI funcional é JSON UTF-8. Implementações internas podem utilizar formatos diferentes somente atrás do wrapper da capability.

Mudança incompatível na forma esperada do objeto de entrada ou saída exige nova versão da capability.

## BLOCKED

Para atingir `refined`, ainda precisam ser definidos:

- taxonomia de códigos de saída;
- limites de tamanho do payload, se necessários;
- comportamento operacional de buffering/materialização para branches paralelos.

## Critérios de aceite

- entrada e saída válidas podem ser parseadas como um único objeto JSON;
- stderr nunca faz parte do resultado funcional;
- uma capability externa pode ser substituída por outra implementation sem alterar a ABI do assembler;
- fan-in produz um único objeto de entrada coerente com o contrato da task.
