# Separação entre contrato lógico e encoding de stream

![ADR](https://img.shields.io/badge/ADR-ADR--0009-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

O normalizador deve descrever o problema independentemente da implementação que irá resolvê-lo.

Cada tarefa precisa declarar os dados disponíveis, o processamento solicitado e a estrutura esperada do resultado. A forma de transporte desses dados pertence à fronteira de execução das capabilities.

## Problema

Misturar tipo lógico e encoding obriga o normalizador a escolher detalhes de stream antes de existir uma capability resolvida.

## Restrições

- a mesma semântica pode possuir implementações diferentes;
- busca de capability precisa comparar entrada e saída logicamente;
- o normalizador não escolhe Bash, comando, aplicação, script, serviço ou encoding específico;
- a ABI entre functions já define JSON UTF-8 como transporte canônico.

## Opções consideradas

### Contrato único com tipo e encoding

Mais simples no schema, porém acopla normalização à execução.

### Contrato lógico separado da ABI de stream

A tarefa descreve forma e significado dos dados; a ABI de execução define como o objeto é transportado.

## Decisão

Separar contrato lógico de transporte.

Cada `NormalizedTask` representa conceitualmente:

1. **input** — campos estruturados disponíveis, incluindo valores literais e `result_ref`;
2. **instruction** — texto objetivo descrevendo a transformação necessária;
3. **output contract** — estrutura tipada esperada do resultado.

O normalizador produz somente o contrato lógico.

Na fronteira entre functions, o transporte canônico é JSON UTF-8 conforme [ADR-0003](../execucao/abi-stdout-stdin.md).

Uma implementation que necessite de flags, argumentos posicionais, arquivos, protocolo próprio ou outro encoding realiza essa adaptação dentro do wrapper da capability.

## Justificativa

A busca passa a comparar o que a tarefa precisa com o que a capability aceita e produz, sem acoplamento ao mecanismo interno de execução.

## Consequências

- MOD-0001 não deve escolher encoding;
- Capability Search pode usar entrada, instrução e saída como dimensões de compatibilidade;
- CTR-0001 continua responsável pelo plano de controle Protobuf;
- o contrato da ABI JSON é documentado separadamente;
- a representação física dos contratos no Protobuf pode evoluir sem alterar sua semântica lógica.

## Dependências

- [ADR-0002](protobuf-e-textproto.md)
- [ADR-0003](../execucao/abi-stdout-stdin.md)

## Critérios de validação

- o contrato lógico representa estrutura, tipos e obrigatoriedade sem escolher comando ou encoding;
- o normalizador não declara JSON, stdin, stdout ou flags como parte da intenção da task;
- compatibilidade lógica é validada antes da composição;
- a fronteira funcional usa a ABI JSON definida pelo ADR-0003.
