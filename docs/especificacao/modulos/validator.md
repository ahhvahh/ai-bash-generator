# Validator

![MOD](https://img.shields.io/badge/MOD-MOD--0004-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Validar deterministicamente o DAG de tasks, capabilities resolvidas e functions geradas antes da materialização do artifact.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [ADR-0003 — ABI JSON](../../adr/execucao/abi-stdout-stdin.md)
- [ADR-0010 — Binding por função](../../adr/execucao/binding-invocacao.md)
- [ADR-0011 — Isolamento de functions](../../adr/execucao/isolamento-functions.md)
- [ADR-0012 — Controle de acesso pelo ambiente](../../adr/seguranca/efeitos-capabilities.md)
- [CTR-0001 — Protobuf](../contratos/pipeline-protobuf.md)
- [CTR-0005 — ABI JSON de functions](../contratos/function-json.md)

## Responsabilidades

A validação prevista inclui:

1. mensagens de controle;
2. DAG e referências;
3. compatibilidade de input e output;
4. versões de capabilities;
5. presença e estrutura dos wrappers Bash;
6. composição determinística de preview;
7. `bash -n`;
8. ShellCheck;
9. dependências externas declaradas.

## Entradas

Conjunto resolvido de tasks com as versões completas das capabilities utilizadas e functions geradas quando houver.

## Saídas

Resultado estruturado com `valid`, conjunto resolvido e issues.

## Restrições

- o script não é executado;
- toda capability precisa apresentar uma function compatível com CTR-0005;
- SCRIPT, APPLICATION e SERVICE devem manter sua integridade externa verificável quando aplicável;
- nova capability produzida por LLM é FUNCTION;
- uma saída não pode alimentar input estruturalmente incompatível;
- routing e Input Binder não substituem transformação funcional;
- ShellCheck indisponível deve resultar em falha explícita na política atual;
- o Validator não concede permissões de execução;
- permissões do artifact são responsabilidade do usuário/processo e ambiente de execução conforme ADR-0012.

**BLOCKED:** isolamento de function ainda não está refinado. Taxonomia final de exit codes e detalhes operacionais de concorrência também permanecem pendentes.

## Critérios de aceite

- ciclos e referências inválidas são rejeitados;
- contratos incompatíveis são rejeitados;
- capability existente sem versão resolvida é rejeitada;
- capability sem wrapper funcional válido é rejeitada;
- o Validator não trata metadados da capability como concessão de privilégios;
- preview não contém composição decidida por inferência;
- falha final de validação impede a criação do artifact.

## Implementação relacionada

Arquitetura-alvo ainda não verificada na implementação atual.
