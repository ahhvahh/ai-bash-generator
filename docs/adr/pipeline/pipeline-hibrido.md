# Pipeline híbrido LLM e determinístico

![ADR](https://img.shields.io/badge/ADR-ADR--0001-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

O processamento possui etapas que exigem interpretação semântica e etapas determinísticas.

## Problema

Usar LLM em todo o pipeline aumentaria variabilidade, contexto e superfície de erro.

## Restrições

- LLM não executa o script gerado.
- Validação e materialização são determinísticas.
- Informação obrigatória ausente não pode ser inventada.

## Opções consideradas

### LLM em todo o pipeline

Maior flexibilidade, porém menor previsibilidade.

### LLM somente onde há interpretação ou geração

Normalização e planejamento ficam no modelo; busca, validação, publicação e materialização ficam na aplicação.

## Decisão

Usar LLM somente em `request-normalizer` e `bash-generator`.

## Justificativa

Reduz contexto, latência e decisões implícitas nas etapas verificáveis.

## Consequências

O pipeline exige contratos explícitos entre etapas e Tool Orchestrator controlado pela aplicação.

## Dependências

- nenhuma

## Critérios de validação

- Somente as duas etapas definidas dependem de inferência.
- O Bash final deriva de um plano validado.
- Informação ausente interrompe o pipeline antes da busca.
