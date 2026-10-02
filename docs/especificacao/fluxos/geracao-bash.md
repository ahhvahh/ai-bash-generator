# Geração de Bash

![FLW](https://img.shields.io/badge/FLW-FLW--0001-bf3989?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)

## Objetivo

Descrever o fluxo completo desde a solicitação até o `BashArtifact`.

## Dependências

- [DSG-0001 — Pipeline de geração](../../desenho/pipeline-geracao.md)
- [MOD-0001 — Request Normalizer](../modulos/request-normalizer.md)
- [MOD-0002 — Capability Search](../modulos/capability-search.md)
- [MOD-0003 — Bash Generator](../modulos/bash-generator.md)
- [MOD-0004 — Validator](../modulos/validator.md)
- [MOD-0005 — Bash Output](../modulos/bash-output.md)
- [ADR-0013 — Sessão do gerador](../../adr/runtime/sessao-gerador.md)

## Gatilho

Solicitação aceita pelo serviço para geração de um artifact Bash.

## Pré-condições

- configuração válida;
- agentes necessários disponíveis;
- dependências determinísticas disponíveis.

## Fluxo principal

1. O Pipeline Manager atribui identidade interna à requisição.
2. O Request Normalizer produz `NormalizedRequest`.
3. A aplicação valida a normalização.
4. Se READY, Capability Search localiza e poda candidatos.
5. O Bash Generator recebe candidatos resumidos.
6. Quando necessário, solicita detalhes ou MCPs pelo Tool Orchestrator.
7. O loop continua até `GenerationPlan` ou falha.
8. O Validator valida plano, contracts, versões, policy e preview.
9. Se permitido, uma única correção pode retornar ao gerador.
10. Com validação válida, publicação e materialização podem ocorrer independentemente.
11. Bash Output produz `BashArtifact`.
12. O serviço devolve o resultado ao cliente conforme a API externa.

## Fluxos alternativos

### Informação ausente

Seguir [FLW-0003](informacao-ausente.md).

### Capability composta

Uma única capability pode substituir várias tarefas quando contratos forem compatíveis.

### Reutilização parcial

Capabilities existentes e FUNCTION gerada podem coexistir no mesmo plano.

## Falhas e tratamento

Erros de parsing, contrato, versão, policy, tool, inferência ou filesystem interrompem a etapa correspondente e retornam erro estruturado.

## Resultado

Artifact materializado, falha estruturada ou pedido por informação ausente.

## BLOCKED

O fluxo não pode atingir `refined` enquanto busca/version pin, binding, contexto e demais contratos dependentes estiverem abertos.

## Critérios de aceite

- LLM não materializa arquivo diretamente.
- Tool call sempre passa pelo Orchestrator.
- O artifact só é criado após validação válida.
- Publicação e materialização não fingem transação distribuída.

## Implementação relacionada

Referências de código não foram verificadas nesta adequação.
