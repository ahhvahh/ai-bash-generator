# Bash Generator

![MOD](https://img.shields.io/badge/MOD-MOD--0003-1f883d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo atual

Gerar código-fonte Bash a partir de uma `NormalizedRequest` validada e dos candidatos retornados pelo Capability Catalog.

Na implementação de referência `main@a734af859d800487b51b5136d5772397dc12ffc6`, o módulo produz Bash diretamente. A produção intermediária de `GenerationPlan` pertence à arquitetura-alvo e ainda não representa o comportamento atual do daemon.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [MOD-0001 — Request Normalizer](request-normalizer.md)
- [MOD-0002 — Capability Search](capability-search.md)
- [PRM-0002 — Prompt do gerador](../prompts/bash-generator.md)
- [OPS-0001 — Manutenção da inferência](../runtime/manutencao-inferencia.md)

## Responsabilidades

- consumir a NormalizedRequest validada;
- respeitar a ordem canônica das tasks;
- respeitar `result_ref` e `depends_on`;
- aceitar outputs sem consumidores quando eles forem resultados válidos;
- reutilizar o mesmo resultado lógico em fan-out;
- respeitar os objetos JSON de definição de entrada e saída;
- considerar os candidatos do catálogo local;
- produzir somente Bash;
- não executar o script;
- não inventar valores;
- produzir fonte compatível com `bash -n`.

## Entradas

O runtime atual monta uma entrada contendo:

- `NormalizedRequest` em TextProto;
- candidatos retornados pelo Capability Catalog.

## Saída

Código-fonte Bash em texto.

## Validação

O pipeline executa `bash -n`. Quando a primeira geração falha, o erro de validação pode ser devolvido ao gerador para uma nova tentativa, dentro do limite configurado.

## Restrições

- nenhuma execução automática do script;
- nenhuma operação destrutiva implícita;
- nenhuma criação de valor ausente da solicitação;
- nenhuma perda de task ou transformação descrita pelo normalizador.

## Evolução arquitetural

`GenerationPlan`, tool loop, binding determinístico e publicação de capabilities permanecem objetivos de arquitetura. Enquanto não estiverem implementados no runtime, devem ser identificados como evolução futura e não como comportamento já disponível.

## Critérios de aceite

- O Bash representa todas as tasks necessárias.
- A ordem lógica e dependências são preservadas.
- O conteúdo retornado contém somente código Bash.
- `bash -n` aprova a saída.
- Os parâmetros e prompt do agente podem ser mantidos conforme OPS-0001 após a implementação do plano de externalização.
