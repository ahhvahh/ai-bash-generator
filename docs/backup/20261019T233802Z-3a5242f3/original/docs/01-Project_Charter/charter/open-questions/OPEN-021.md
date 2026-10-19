# OPEN-021 — Cancelamento, tempo limite e falhas operacionais

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Que garantias o serviço deve oferecer para encerrar solicitações e atividades automáticas quando ocorrer cancelamento, indisponibilidade ou timeout?

## Contexto para refinamento

Solicitações podem ultrapassar o tempo de resposta esperado, perder conexão com o solicitante ou precisar ser canceladas durante geração, inferência, consulta externa ou execução. Foram consideradas interrupção ordenada, propagação do cancelamento e retorno de erros estruturados. Ainda é necessário definir o que deve ser garantido ao usuário, sem escolher protocolos ou estratégias internas.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- O que deve acontecer com tarefas e recursos em uso após cancelamento ou timeout?
- Quais limites máximos e políticas de espera devem ser oferecidos?
- Que informação mínima comprova se houve execução parcial ou se nada foi alterado?

## Impacto

Afeta segurança operacional, limite de consumo de recursos e previsibilidade de falhas.

## Bloqueadora

Sim — comportamento seguro de interrupção de execução precisa ser delimitado no Charter.

## Próxima ação

Estabelecer compromissos de resultado do cancelamento e de encerramento seguro; detalhar propagação na etapa Scope.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-022](OPEN-022.md)
