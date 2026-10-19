# Controle de acesso pelo ambiente de execução

![ADR](https://img.shields.io/badge/ADR-ADR--0012-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

O `BashArtifact` pode operar sobre recursos do ambiente e invocar aplicações usadas para trabalhos pontuais.

A segurança da execução precisa ter uma fronteira clara sem exigir que o catálogo tente modelar e autorizar todos os possíveis efeitos de cada capability.

## Problema

Uma política baseada em efeitos declarados por capability duplicaria parcialmente controles já existentes no ambiente operacional e exigiria uma taxonomia ampla de filesystem, rede, processos, serviços e privilégios.

O ponto efetivo de autorização é quem executa o artifact e quais recursos esse executor consegue acessar.

## Restrições

- o LLM não concede permissões;
- o catálogo não amplia permissões do executor;
- a geração do artifact não executa o script;
- o artifact herda as permissões e limitações do usuário/processo que o executa;
- aplicações externas somente podem ser utilizadas quando estiverem acessíveis nesse ambiente de execução.

## Opções consideradas

### CapabilityEffects estruturado

Modelar efeitos e aplicar autorização individual por capability.

### Controle pelo ambiente de execução

Restringir o usuário/processo executor e disponibilizar apenas os recursos e aplicações que ele pode utilizar.

## Decisão

Na V1, a autorização operacional será controlada pelo **ambiente de execução e pela identidade que executa o `BashArtifact`**.

O artifact:

- executa com as permissões herdadas do usuário/processo executor;
- não recebe permissões adicionais do catálogo, da LLM ou do assembler;
- somente consegue acessar recursos permitidos pelo ambiente;
- somente consegue utilizar aplicações disponibilizadas e acessíveis para esse executor.

O catálogo de capabilities não precisa manter uma taxonomia obrigatória de efeitos para autorizar a execução.

Se `risk_level` ou informações semelhantes permanecerem no catálogo, terão caráter descritivo e não serão a fonte de autorização da V1.

A disponibilidade de aplicações e demais dependências continua sendo tratada como requisito de runtime, separado da autorização.

## Justificativa

O controle fica no mecanismo que efetivamente possui autoridade sobre filesystem, processos, serviços e aplicações: o ambiente onde o artifact é executado.

Isso reduz complexidade no catálogo e impede que uma decisão produzida pela LLM seja interpretada como concessão de privilégio.

## Consequências

- `CapabilityEffects` não é requisito obrigatório da V1;
- Capability Search não filtra funções por efeitos autorizados;
- Validator não concede nem revoga permissões;
- ausência de permissão ou de uma aplicação necessária resulta em falha de runtime conforme os contratos de execução;
- restrições do usuário/processo executor devem ser definidas no ambiente de execução;
- manifesto e disponibilidade de dependências continuam sendo refinados separadamente.

## Dependências

- [ADR-0005](../integracoes/orquestracao-mcp.md)

## Critérios de validação

- o artifact não depende de autorização concedida pelo LLM;
- o catálogo não é fonte de privilégios de execução;
- permissões efetivas são as do usuário/processo executor;
- aplicações externas somente são utilizáveis quando disponíveis e acessíveis ao executor;
- falha de acesso é tratada como falha de runtime, não como autorização implícita.
