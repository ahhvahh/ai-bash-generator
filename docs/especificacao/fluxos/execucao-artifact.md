# Execução futura do BashArtifact

![FLW](https://img.shields.io/badge/FLW-FLW--0006-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Delimitar a execução futura do artifact, separando-a do fluxo de geração.

## Dependências

- [ADR-0003 — ABI stdout/stdin](../../adr/execucao/abi-stdout-stdin.md)
- [MOD-0005 — Bash Output](../modulos/bash-output.md)

## Gatilho

O usuário ou outro executor inicia explicitamente um artifact previamente gerado.

## Pré-condições

- artifact materializado;
- dependências de runtime disponíveis;
- permissões de execução concedidas quando necessárias.

## Fluxo principal

Para functions incorporadas:

1. O artifact carrega apenas definições validadas.
2. Executa a primeira capability.
3. Encadeia stdout em stdin das etapas seguintes conforme plano materializado.
4. Entrega o resultado final em stdout.

Para dependências externas, o comportamento final depende da política de portabilidade ainda não definida.

## Fluxos alternativos

### SELF_CONTAINED

Somente comportamento incorporado e dependências de sistema declaradas.

### HOST_BOUND

Depende de aplicação, serviço, socket ou recurso do host. A política de guardas de checksum ainda está pendente.

## Falhas e tratamento

Exit code e stderr seguem contratos das capabilities e do artifact.

## Resultado

Saída funcional ou falha de runtime.

## BLOCKED

A documentação ainda precisa decidir:

- portabilidade SELF_CONTAINED versus HOST_BOUND;
- manifesto de dependências;
- verificação de checksum em runtime;
- semântica específica de exit codes.

## Critérios de aceite

- Geração nunca executa automaticamente o artifact.
- Dependências externas são declaradas.
- O modo de portabilidade é inequívoco.
- Runtime guards são definidos quando necessários.
