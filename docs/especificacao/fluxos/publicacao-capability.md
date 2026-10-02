# Publicação de capability

![FLW](https://img.shields.io/badge/FLW-FLW--0002-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Publicar uma nova capability validada de forma idempotente, sem ativação automática.

## Dependências

- [ADR-0004 — Catálogo versionado](../../adr/persistencia/catalogo-capabilities.md)
- [ADR-0006 — Publicação e materialização](../../adr/pipeline/publicacao-materializacao.md)
- [ADR-0007 — Capabilities geradas](../../adr/geracao/capabilities-geradas.md)
- [PST-0001 — Persistência do catálogo](../persistencia/catalogo-capabilities.md)

## Gatilho

Uma geração validada contém uma nova FUNCTION elegível para publicação.

## Pré-condições

- validação concluída com sucesso;
- capability possui interface e implementation validadas;
- request e idempotency key disponíveis.

## Fluxo principal

1. A aplicação calcula fingerprint canônica conforme regra vigente.
2. O Publisher verifica equivalência protegida por garantia transacional.
3. Se equivalente existir, reutiliza a versão existente.
4. Caso contrário, cria identidade ou nova versão imutável.
5. A nova versão entra em estado `candidate`.
6. Retorna a identidade/version da publicação.

## Fluxos alternativos

### Conflito concorrente

A restrição de unicidade vence a corrida; o fluxo consulta e reutiliza a versão equivalente.

## Falhas e tratamento

Falha de publicação não desfaz um artifact materializado com sucesso e não corrompe o catálogo.

## Resultado

Versão candidate criada ou versão equivalente reutilizada.

## BLOCKED

Canonicalização da fingerprint, ator do lifecycle administrativo e migrations permanecem pendentes.

## Critérios de aceite

- Retry da mesma solicitação não duplica publicação.
- FUNCTION gerada não é ativada automaticamente.
- Versão publicada é imutável.
