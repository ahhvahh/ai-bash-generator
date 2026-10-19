# Capability Search

![MOD](https://img.shields.io/badge/MOD-MOD--0002-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Localizar capabilities ativas capazes de resolver cada `NormalizedTask`, sem usar LLM.

## Dependências

- [DSG-0002 — Catálogo de capabilities](../../desenho/catalogo-capabilities.md)
- [ADR-0008 — Pinagem de versão](../../adr/catalogo/pinagem-versao-capability.md)
- [ADR-0009 — Contrato lógico e stream](../../adr/contratos/contrato-logico-e-stream.md)
- [ADR-0010 — Binding por função](../../adr/execucao/binding-invocacao.md)
- [PST-0001 — Persistência do catálogo](../persistencia/catalogo-capabilities.md)

## Responsabilidades

- localizar capability por correspondência exata de propósito, contrato de input e contrato de output;
- rejeitar qualquer diferença entre os três elementos;
- considerar somente identities habilitadas e versões ativas;
- retornar a versão ativa mais recente da capability encontrada por `capability_version_id`;
- permitir zero candidatos como resultado válido;
- evitar LLM no processo normal de busca e pruning.

## Entradas

`SearchCapabilitiesRequest` contendo `NormalizedRequest` READY e orçamento de busca.

Para cada task, a busca utiliza três dimensões lógicas e exige igualdade:

1. **input** — contrato lógico de entrada idêntico;
2. **instruction/purpose** — propósito idêntico;
3. **output** — contrato lógico de saída idêntico.

A V1 não usa similaridade, score, ranking ou aproximação. Qualquer diferença em uma das três dimensões significa que a capability não atende a task.

## Saídas

Zero ou uma capability compatível por task, identificada por sua versão ativa mais recente em `capability_version_id`.

A definição completa é carregada posteriormente diretamente por esse identificador e deve incluir a função Bash que expõe a capability ao assembler conforme ADR-0010.

## Restrições

- FTS, ranking semântico ou matching aproximado não participam da resolução normativa da V1.
- `search_capabilities` não registra uso; o registro ocorre quando a versão completa é carregada.
- O tipo interno de implementation não altera a interface apresentada ao assembler.
- Ausência de correspondência exata é resultado válido e encaminha a task para geração de nova FUNCTION.

O gate de desenho está liberado por DSG-0002 em `finalized`. A especificação permanece em `refinement` até que seus contratos e dependências documentais associados estejam suficientemente definidos.

## Critérios de aceite

- somente versões elegíveis entram na busca;
- input, propósito e output precisam coincidir de forma exata;
- diferenças de contrato não são resolvidas por ranking;
- ausência de correspondência exata encaminha a task para geração de nova FUNCTION;
- a busca retorna o `capability_version_id` da versão ativa mais recente;
- a versão escolhida permanece pinada até o fim da requisição.
