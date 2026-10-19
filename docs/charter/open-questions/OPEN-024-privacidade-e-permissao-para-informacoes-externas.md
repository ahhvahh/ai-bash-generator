# OPEN-024 — Privacidade e permissão para informações externas

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais informações o produto pode compartilhar com provedores ou integrações externas, e como o solicitante controla essa autorização?

## Contexto para refinamento

O sistema pode, quando configurado, utilizar processamento externo e dados obtidos de integrações. Isso introduz exposição potencial de informações do ambiente, resultados não confiáveis e risco de acesso indevido. A compatibilidade com funcionamento offline permanece um compromisso, e a autorização para enviar dados não deve ser inferida da mera disponibilidade de uma integração.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Que classes de informação não podem sair do ambiente local?
- Como o administrador autoriza ou restringe cada finalidade de processamento externo?
- Que registros de uso e tratamento de dados são indispensáveis sem revelar conteúdo sensível?

## Impacto

Afeta confidencialidade das solicitações e aderência à alternativa offline.

## Bloqueadora

Sim — política de saída de dados interfere diretamente em CON-001.

## Próxima ação

Decidir princípio de minimização de dados e autorização; registrar restrição canônica apropriada no Charter.

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [CON-001](../conditions/CON-001-operacao-offline-e-apis-externas-opcionais.md)
- [NOBJ-001](../non-objectives/NOBJ-001-nao-executar-alem-das-permissoes-concedidas-ao-usuario-do-servico.md)
- [OPEN-006](OPEN-006-controle-do-acesso-a-ferramentas-e-integracoes.md)
