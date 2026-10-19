# OPEN-023 — Governança de capacidades publicadas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quem autoriza uma nova capacidade a ficar disponível para reutilização e sob quais evidências e condições de reversão?

## Contexto para refinamento

Uma capacidade produzida pelo sistema pode existir como candidata sem estar imediatamente disponível a outros pedidos. Foi considerada uma etapa de aprovação ou ativação para evitar reutilizar soluções ainda não verificadas, com possibilidade de bloqueio ou substituição de versões. Permanecem em aberto os responsáveis e os critérios para cada transição.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais evidências tornam uma capacidade segura e apta à reutilização?
- Quem pode ativar, suspender ou substituir uma capacidade no ambiente local?
- Que histórico de mudanças e uso precisa ser preservado para auditoria?

## Impacto

Afeta confiabilidade, responsabilização e permissões para o reaproveitamento automático.

## Bloqueadora

Sim — ativação de capacidade automática afeta a fronteira de segurança do produto.

## Próxima ação

Definir política de aprovação em alto nível e se a ativação pode ser automática; encaminhar operações de administração ao Scope.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-002](../objectives/OBJ-002.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-005](OPEN-005.md)

## Relação com descoberta e composição — sem promoção de elegibilidade

**DOCUMENTED:** a descoberta por [OBJ-002](../objectives/OBJ-002.md) e a composição de [OBJ-006](../objectives/OBJ-006.md) recuperam apenas funções **elegíveis e com versão ativa selecionada**; novas funções geradas podem ser candidatas, mas sua validação para a requisição corrente não implica automaticamente ativação para reutilizações futuras. A pesquisa no catálogo não executa funções nem altera seus privilégios. 

**PENDING —** política de ativação, suspensão, substituição, responsáveis e evidências de segurança, ainda bloqueadora para o gate; a atualização atual não aprova publicação ou ativação automática de novas capacidades.
