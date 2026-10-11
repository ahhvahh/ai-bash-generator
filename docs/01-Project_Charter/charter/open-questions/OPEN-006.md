# OPEN-006 — Controle do acesso a ferramentas e integrações

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

O produto deve permitir integrações durante a geração e quais limites de autorização, rastreabilidade e confiança são obrigatórios?

## Contexto para refinamento

Para consultar ferramentas externas durante o processamento, foi considerada uma camada de controle da aplicação responsável por permissões, limites, validação de respostas e auditoria. Resultados externos podem trazer dados incorretos ou instruções hostis e não devem ampliar a autoridade do sistema. A necessidade de integração permanece subordinada ao propósito do produto.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais classes de operações externas podem ser permitidas e quais devem permanecer excluídas?
- Que autorização e rastreabilidade devem ser exigidas independentemente da ferramenta escolhida?
- Quais informações podem ser encaminhadas a terceiros sem comprometer segurança e privacidade?

## Impacto

Afeta exposição de dados a terceiros e o limite de autoridade delegado ao processamento automático.

## Bloqueadora

Sim — as permissões e o uso de integrações afetam diretamente as restrições declaradas no Charter.

## Próxima ação

Confirmar a política de autorização de integrações em nível de produto; detalhar MCP, schemas e timeouts em Scope/Implementation.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [CON-001](../constraints/CON-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
