# Catálogo de capabilities

![DSG](https://img.shields.io/badge/DSG-DSG--0002-0550ae?style=flat-square)
![Status](https://img.shields.io/badge/Status-finalized-0a7ea4?style=flat-square)

## Objetivo

Representar busca, versionamento, contratos lógicos, wrappers funcionais, lifecycle, telemetria e publicação de capabilities.

## Dependências

- [ADR-0004 — PostgreSQL e versões imutáveis](../adr/persistencia/catalogo-capabilities.md)
- [ADR-0008 — Identidade e pinagem de versão](../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função](../adr/execucao/binding-invocacao.md)
- [ADR-0012 — Controle de acesso pelo ambiente](../adr/seguranca/efeitos-capabilities.md)

## Nível C4

`Component`

## Diagrama

```mermaid
flowchart LR
    T[NormalizedTask] --> S[Capability Search]
    S --> C[Capability]
    C --> V[active_version_id]
    V --> CV[Capability Version]
    CV --> W[Wrapper Bash]
    W --> A[Assembler]
```

## Elementos e responsabilidades

### Capability

Mantém a identidade lógica usada para localizar uma função por:

- contrato de entrada;
- contrato de saída;
- propósito;
- versão ativa.

### Capability Version

Mantém uma versão imutável da implementação, incluindo contratos, wrapper e dependências necessárias para reproduzir a solução.

Uma melhoria de implementação ou performance que preserve entrada, saída e propósito cria uma nova versão da mesma capability.

### Capability Search

Usa matching exato de entrada, saída e propósito e retorna o `capability_version_id` ativo.

Não existe ranking por similaridade na V1.

### Wrapper funcional

Cada versão resolvida apresenta ao assembler uma função Bash uniforme, independentemente de a implementação real ser FUNCTION, SCRIPT, APPLICATION ou SERVICE.

### Autorização de execução

O catálogo não concede privilégios e não decide autorização por efeitos da capability.

As permissões efetivas pertencem ao usuário/processo e ao ambiente que futuramente executarem o `BashArtifact`, conforme ADR-0012.

A declaração e disponibilidade de dependências externas permanecem responsabilidades de runtime e das especificações correspondentes.

## Relações relevantes

A busca só considera correspondência exata de entrada, saída e propósito.

A definição completa é carregada diretamente pelo `capability_version_id` retornado pela busca, evitando nova resolução da versão.

O assembler recebe wrappers funcionais e não precisa conhecer detalhes específicos da implementação concreta.

## Critérios de finalização

- ADR-0004 refinado;
- ADR-0008 refinado;
- ADR-0009 refinado;
- ADR-0010 refinado;
- ADR-0012 refinado;
- identidade, versão, busca e fronteira de autorização definidos.

Os critérios acima estão satisfeitos para o escopo deste desenho.
