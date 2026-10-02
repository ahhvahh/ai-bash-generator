# Catálogo de capabilities

**ID:** PST-0001  
**Status:** refinement

## Objetivo

Especificar a persistência local de identities, versões, lifecycle e uso de capabilities em PostgreSQL.

## Dependências

- [ADR-0004 — PostgreSQL e versões imutáveis](../../adr/persistencia/catalogo-capabilities.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [DSG-0002 — Catálogo de capabilities](../../desenho/catalogo-capabilities.md)

## Conexão

A configuração documentada usa PostgreSQL local por Unix Domain Socket, banco e usuário dedicados e `sslmode=disable` para o socket local.

## Entidades

### capability

Responsável pela identidade lógica e referência da versão ativa.

Campos estáveis já reconhecidos:

- chave lógica única;
- enabled;
- `active_version_id`.

**BLOCKED:** ADR-0008 precisa decidir quais metadados pesquisáveis permanecem na identidade e quais migram para a versão.

### capability_version

Cada linha representa uma definição imutável de uma capability.

Conteúdo documentado inclui:

- `capability_id`;
- versão lógica;
- lifecycle status;
- contratos;
- implementation;
- dependências;
- risco/complexidade;
- checksum;
- fingerprint;
- criação.

Deve existir unicidade por `capability_id + version` e no máximo uma versão ativa por capability.

### capability_usage

Evento append-only que registra que uma requisição carregou a definição completa de uma versão.

Campos mínimos:

- identificador;
- `capability_version_id`;
- `request_id`;
- `requested_at`.

Deve existir unicidade por `request_id + capability_version_id`.

## Lifecycle

Estados documentados:

`candidate → validated → approved → active → deprecated|blocked`

A busca normal somente considera capability habilitada com versão ativa.

## Publicação idempotente

Publicação usa `idempotency_key` e fingerprint. A persistência deve possuir garantia de unicidade suficiente para impedir publicação concorrente equivalente; conflito deve reutilizar a versão existente quando semanticamente idêntica.

## Busca

Candidate retrieval usa intenção e PostgreSQL Full Text Search. FTS apenas localiza candidatos; compatibilidade é verificada fora do banco.

**BLOCKED:** ranking, tie-break, canonicalização de fingerprint, migrations e `risk_level` tipado permanecem pendentes.

## Exclusão

A documentação anterior usava `ON DELETE CASCADE` entre capability e versões. Como a política completa de retenção e auditoria não foi reavaliada nesta reorganização, não expandir essa regra para outras relações sem decisão explícita.

## Critérios de aceite

- Versões publicadas não são alteradas in-place.
- Uma capability não aponta para versão de outra identidade.
- Somente uma versão fica ativa por capability.
- Uso referencia a versão efetivamente carregada.
- Conflito concorrente não cria duplicata equivalente.
