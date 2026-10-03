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

Campos estáveis:

- chave lógica única;
- contrato lógico de entrada usado no matching;
- contrato lógico de saída usado no matching;
- propósito usado no matching;
- enabled;
- `active_version_id`.

Entrada, saída e propósito formam a identidade funcional usada pela busca na V1. A comparação é exata; não há matching parcial ou por similaridade.

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

A resolução normativa da V1 procura uma capability com igualdade exata em:

1. contrato lógico de input;
2. propósito;
3. contrato lógico de output.

Não há ranking, score, FTS semântico ou desempate por aproximação.

Encontrada a identidade lógica, a busca retorna diretamente seu `active_version_id`, correspondente à versão ativa mais recente. O restante do pipeline usa esse `capability_version_id` sem resolver novamente a versão.

Se não existir correspondência exata, a busca retorna ausência de solução catalogada.

**BLOCKED:** canonicalização de fingerprint, migrations e `risk_level` tipado permanecem pendentes.

## Exclusão

A documentação anterior usava `ON DELETE CASCADE` entre capability e versões. Como a política completa de retenção e auditoria não foi reavaliada, não expandir essa regra para outras relações sem decisão explícita.

## Critérios de aceite

- versões publicadas não são alteradas in-place;
- uma capability não aponta para versão de outra identidade;
- entrada, saída e propósito precisam coincidir exatamente para reutilização;
- somente uma versão fica ativa por capability;
- nova otimização de implementação cria nova versão da mesma identidade funcional;
- a busca devolve o `capability_version_id` ativo e o detalhe usa o mesmo identificador;
- a versão carregada contém contratos e wrapper suficientes para validação e composição;
- uso referencia a versão efetivamente carregada;
- conflito concorrente não cria duplicata equivalente.
