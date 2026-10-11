# OPEN-013 — Identidade e privilégios de execução

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

A execução automática deve ocorrer sempre pela identidade dedicada do serviço e exclusivamente com as permissões que o administrador lhe atribuir?

## Contexto para refinamento

A baseline atual estabelece execução automática com a identidade dedicada do serviço e somente com permissões atribuídas pelo administrador do sistema operacional. Outra alternativa considerada anteriormente associava a autorização ao usuário ou processo que executa cada artefato. É necessária decisão explícita sobre a fronteira de identidade e autoridade; nenhuma dessas alternativas deve ser inferida a partir de documentos de implementação.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- A conta dedicada deve ser sempre a única identidade executora?
- Como são verificadas as permissões e os grupos definidos pelo administrador?
- Que comportamento é obrigatório quando faltar autorização para acessar um recurso?

## Impacto

Define a fronteira de segurança, responsabilidade operacional e controles exigidos pelo produto.

## Bloqueadora

Sim — divergência material entre referências históricas e Charter vigente.

## Próxima ação

Confirmar o ator executor e harmonizar PCH-001/NOBJ-001 com os requisitos futuros, registrando a decisão somente no Charter.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-022](OPEN-022.md)
