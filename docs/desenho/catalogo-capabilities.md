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

Já definidos pelo ADR-0008:

- matching exato por contrato de entrada, contrato de saída e propósito;
- `capability_version_id` como pinagem entre search e detail;
- versões imutáveis para evolução de implementação;
- ausência de ranking por similaridade na V1.

Ainda estão em decisão:

- efeitos estruturados usados por policy.

## Relações relevantes

Capability Search avalia input, instruction e output da task contra as versões elegíveis.

A busca só considera correspondência exata de entrada, saída e propósito. O detalhe consumido pelo pipeline é carregado diretamente pelo `capability_version_id` retornado pela busca.

Depois de resolvida, a implementation concreta fica atrás do wrapper funcional; o assembler não diferencia FUNCTION, SCRIPT, APPLICATION ou SERVICE.

## Critérios para finalização

- ADR-0008 em `refined`;
- ADR-0012 em `refined`;
- definição inequívoca de policy metadata;
- persistência do wrapper e dos contratos suficientemente especificada.
