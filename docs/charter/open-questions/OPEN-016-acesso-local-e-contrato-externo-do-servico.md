# OPEN-016 — Acesso local e contrato externo do serviço

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais operações externas e garantias de erro, cancelamento e controle local o produto precisa oferecer?

## Contexto para refinamento

O produto precisa receber solicitações, acompanhar seu estado e devolver resultados ou falhas de forma confiável aos processos que o utilizam. Foi considerada uma comunicação local com tratamento de correlação, cancelamento e limites de mensagem, mas os detalhes de protocolo não são compromisso do Charter. A intenção é manter uma fronteira de acesso previsível e adequada às permissões locais.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais tipos de solicitação e resultado devem ser acessíveis ao solicitante local?
- O usuário precisa consultar progresso e cancelar operações em andamento?
- Quais garantias de isolamento e não exposição pública são obrigatórias?

## Impacto

Afeta capacidade de uso por clientes locais e previsibilidade do atendimento.

## Bloqueadora

Não — formato de mensagens, framing e transporte são responsabilidades posteriores.

## Próxima ação

Confirmar operações externas mínimas e limites de acesso; detalhar contratos em Scope.

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-001](../objectives/OBJ-001-gerar-scripts-bash-a-partir-de-linguagem-natural.md)
- [CON-001](../conditions/CON-001-operacao-offline-e-apis-externas-opcionais.md)
- [NOBJ-001](../non-objectives/NOBJ-001-nao-executar-alem-das-permissoes-concedidas-ao-usuario-do-servico.md)
