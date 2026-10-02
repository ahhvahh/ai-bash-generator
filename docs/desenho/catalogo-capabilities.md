# Catálogo de capabilities

![DSG](https://img.shields.io/badge/DSG-DSG--0002-0550ae?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Representar busca, versionamento, contratos lógicos, wrappers funcionais, lifecycle, telemetria e publicação de capabilities.

## Dependências

- [ADR-0004 — PostgreSQL e versões imutáveis](../adr/persistencia/catalogo-capabilities.md)
- [ADR-0008 — Identidade e pinagem de versão](../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função](../adr/execucao/binding-invocacao.md)
- [ADR-0012 — Efeitos e autorização](../adr/seguranca/efeitos-capabilities.md)

## Nível C4

`Component`

## Diagrama

BLOCKED. O desenho final não deve congelar a posição dos metadados pesquisáveis nem o contrato de autorização antes dos ADRs dependentes serem refinados.

## Elementos e responsabilidades

Já são estáveis:

- identidade lógica da capability;
- versões imutáveis;
- versão ativa única;
- input e output contracts lógicos;
- descrição funcional usada para localizar candidatos;
- wrapper Bash uniforme por versão para composição no artifact;
- telemetria por versão;
- publicação idempotente.

Ainda estão em decisão:

- campos estáveis versus versionados;
- pinagem entre search e detail;
- efeitos estruturados usados por policy;
- ranking e desempate da busca.

## Relações relevantes

Capability Search avalia input, instruction e output da task contra as versões elegíveis.

O detalhe consumido pelo pipeline precisa corresponder exatamente à versão avaliada no pruning.

Depois de resolvida, a implementation concreta fica atrás do wrapper funcional; o assembler não diferencia FUNCTION, SCRIPT, APPLICATION ou SERVICE.

## Critérios para finalização

- ADR-0008 em `refined`;
- ADR-0012 em `refined`;
- definição inequívoca de identidade, versão, search candidate e policy metadata;
- persistência do wrapper e dos contratos suficientemente especificada.
