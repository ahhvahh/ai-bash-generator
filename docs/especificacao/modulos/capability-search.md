# Capability Search

![MOD](https://img.shields.io/badge/MOD-MOD--0002-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-backlog-6e7781?style=flat-square)

## Objetivo

Localizar capabilities ativas capazes de resolver cada `NormalizedTask`, sem usar LLM.

## Dependências

- [DSG-0002 — Catálogo de capabilities](../../desenho/catalogo-capabilities.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função](../../adr/execucao/binding-invocacao.md)
- [PST-0001 — Persistência do catálogo](../persistencia/catalogo-capabilities.md)

## Responsabilidades

- localizar candidatos pela intenção funcional da task;
- comparar o contrato de input exigido pela capability com os dados disponíveis na task;
- comparar o output da capability com o output contract esperado;
- podar candidatos por lifecycle, policy e compatibilidade estrutural;
- retornar a versão exata avaliada;
- permitir zero candidatos como resultado válido;
- evitar LLM no processo normal de busca e pruning.

## Entradas

`SearchCapabilitiesRequest` contendo `NormalizedRequest` READY e orçamento de busca.

Para cada task, a busca utiliza três dimensões lógicas:

1. **input** — a capability aceita os dados que a task possui;
2. **instruction** — a capability realiza o processamento solicitado;
3. **output** — a capability produz estrutura compatível com o contrato esperado.

## Saídas

Candidatos por task, sempre associados à versão específica avaliada.

A definição completa da versão carregada posteriormente deve incluir a função Bash que expõe a capability ao assembler conforme ADR-0010.

## Restrições

- FTS ou busca textual pode localizar candidatos, mas não substitui validação de contratos.
- `search_capabilities` não registra uso; o registro ocorre quando a versão completa é carregada.
- O tipo interno de implementation não altera a interface apresentada ao assembler.

**BLOCKED:** DSG-0002 ainda não está `finalized` e ADR-0008 ainda precisa fechar a pinagem da versão pesquisada.

## Critérios de aceite

- somente versões elegíveis entram na busca;
- input, instruction e output participam da decisão de compatibilidade;
- zero candidatos encaminha a task para geração de nova FUNCTION, sem inventar uma solução;
- um candidato escolhido permanece pinado à versão efetivamente validada e carregada;
- limites globais e por task são respeitados.
