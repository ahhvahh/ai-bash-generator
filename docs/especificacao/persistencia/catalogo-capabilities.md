# Catálogo de capabilities

**ID:** PST-0001  
**Status:** refinement

## Objetivo

Especificar a persistência local de identities, versões, contratos, implementations, wrappers funcionais, lifecycle e uso de capabilities em PostgreSQL.

## Dependências

- [ADR-0004 — PostgreSQL e versões imutáveis](../../adr/persistencia/catalogo-capabilities.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função](../../adr/execucao/binding-invocacao.md)
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

**BLOCKED:** ADR-0008 precisa decidir quais metadados pesquisáveis permanecem na identidade e quais pertencem à versão.

### capability_version

Cada linha representa uma definição imutável de uma capability.

A versão precisa preservar informação suficiente para reproduzir a solução avaliada pelo pipeline, incluindo:

- `capability_id`;
- versão lógica;
- lifecycle status;
- descrição funcional pesquisável;
- contrato lógico de input;
- contrato lógico de output;
- tipo e definição da implementation;
- wrapper Bash compatível com a ABI JSON, ou referência imutável suficiente para obtê-lo;
- dependências;
- risco/complexidade;
- checksum;
- fingerprint;
- criação.

O wrapper é a interface utilizada pelo assembler. APPLICATION, SCRIPT e SERVICE permanecem tipos internos da implementation e não alteram a ABI exposta.

Deve existir unicidade por `capability_id + version` e no máximo uma versão ativa por capability.

A forma física final dos campos continua dependente do desenho e dos contratos refinados; este documento não fixa coluna ou tipo SQL ainda não decidido.

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

Candidate retrieval pode usar intenção e PostgreSQL Full Text Search.

A seleção precisa considerar:

1. compatibilidade do input lógico;
2. compatibilidade semântica com a instruction;
3. compatibilidade do output lógico.

FTS apenas localiza candidatos; compatibilidade é verificada fora do banco.

**BLOCKED:** ranking, tie-break, canonicalização de fingerprint, migrations, `risk_level` tipado e posição final dos metadados versionáveis permanecem pendentes.

## Exclusão

A documentação anterior usava `ON DELETE CASCADE` entre capability e versões. Como a política completa de retenção e auditoria não foi reavaliada, não expandir essa regra para outras relações sem decisão explícita.

## Critérios de aceite

- versões publicadas não são alteradas in-place;
- uma capability não aponta para versão de outra identidade;
- somente uma versão fica ativa por capability;
- a versão carregada contém contratos e wrapper suficientes para validação e composição;
- uso referencia a versão efetivamente carregada;
- conflito concorrente não cria duplicata equivalente.
