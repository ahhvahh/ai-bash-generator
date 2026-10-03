# Identidade, matching exato e pinagem de versão da capability

![ADR](https://img.shields.io/badge/ADR-ADR--0008-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

A busca precisa localizar uma função reutilizável a partir do objeto de entrada, objeto de saída e propósito esperado.

Uma mesma função lógica pode receber novas versões para melhorar desempenho ou sua implementação sem alterar o contrato funcional esperado.

## Problema

A busca não pode escolher entre candidatos por similaridade, score ou interpretação semântica quando o catálogo já possui uma função exatamente compatível.

Também é necessário garantir que a versão carregada seja exatamente a versão selecionada no catálogo, preservando histórico e permitindo evolução da implementação.

## Restrições

- entrada, saída e propósito precisam coincidir de forma exata;
- matching parcial, fuzzy ou por ranking não faz parte da V1;
- versões publicadas permanecem imutáveis;
- uma nova implementação otimizada não altera versões anteriores;
- o pipeline deve carregar a versão exata retornada pela busca.

## Decisão

A busca de capability na V1 usa correspondência exata entre três elementos:

1. contrato lógico de entrada;
2. contrato lógico de saída;
3. propósito da função.

Somente uma capability cuja entrada, saída e propósito sejam idênticos aos requisitos da task é considerada compatível.

Depois de localizada a capability lógica compatível, a busca retorna sua versão ativa mais recente por `capability_version_id`.

A versão retornada fica pinada durante todo o processamento da requisição. O carregamento posterior da definição completa usa diretamente esse `capability_version_id`; não ocorre nova resolução de versão.

Uma refatoração destinada a melhorar desempenho ou implementação cria uma nova `capability_version`. As versões anteriores permanecem imutáveis para rastreabilidade.

## Matching

Na V1:

- não existe score de similaridade;
- não existe seleção por aproximação;
- não existe desempate entre contratos diferentes;
- diferença em entrada, saída ou propósito significa incompatibilidade;
- ausência de correspondência exata encaminha a task para o fluxo de geração de nova FUNCTION.

## Versionamento

A identidade lógica da capability permanece estável enquanto entrada, saída e propósito permanecerem os mesmos.

Mudanças de implementação que preservem esses três elementos geram nova versão da mesma capability.

Quando uma nova versão se torna a versão ativa, `active_version_id` passa a apontar para ela. A busca devolve esse identificador de versão e o restante do pipeline mantém a pinagem.

## Catálogo de objetos padrão

Um catálogo de objetos/contratos padrão pode ser avaliado futuramente para aumentar o reúso de estruturas de entrada e saída.

Essa possibilidade não altera a regra atual de matching exato e não é requisito para liberar esta decisão.

## Justificativa

A regra elimina ambiguidades de ranking na V1 e permite otimizar uma função sem alterar sua identidade funcional nem perder versões anteriores.

## Consequências

- Capability Search pode ser determinístico sem LLM;
- ranking e desempate por similaridade deixam de ser requisito da V1;
- `capability_version_id` é a chave canônica para carregar a versão resolvida;
- metadados de implementação e conteúdo versionável pertencem à versão;
- DSG-0002 não depende mais de decisão de ranking ou pinagem, mas continua sujeito às demais dependências declaradas.

## Dependências

- [ADR-0004](../persistencia/catalogo-capabilities.md)

## Critérios de validação

- entrada, saída e propósito são comparados por igualdade;
- diferença em qualquer um dos três impede reutilização;
- a busca retorna `capability_version_id`;
- o detalhe carrega exatamente o mesmo `capability_version_id`;
- nova otimização de implementação cria nova versão;
- versões anteriores não são alteradas in-place.
