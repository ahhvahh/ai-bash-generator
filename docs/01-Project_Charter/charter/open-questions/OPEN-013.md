# OPEN-013 — Identidade e privilégios de execução

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Que garantias confirmam o uso exclusivo da conta dedicada do serviço e o respeito às permissões que o administrador lhe atribuiu?

## Contexto para refinamento

A identidade executora foi definida pelo responsável pelo projeto: scripts liberados são executados sempre pelo usuário dedicado do serviço, e não pela identidade do solicitante. A conta e seus grupos de acesso são administrados pelo responsável pelo sistema operacional.

A liberação por regras da aplicação não substitui a verificação das permissões efetivas do SO, conforme [NOBJ-001](../non-objectives/NOBJ-001.md) e [OPEN-020](OPEN-020.md).

## Pontos para deliberação

**Decisão funcional aprovada — 11/10/2026:** o serviço executor deverá sempre usar uma conta de usuário com acessos controlados pelo administrador do SO, sem elevar seus próprios privilégios ou assumir os privilégios de quem fez a requisição.

**Permanecem em refinamento:**
- Como comprovar, antes da execução, que as permissões e os grupos efetivos são compatíveis com a operação?
- Qual falha deverá ser devolvida quando o sistema operacional negar a operação?
- Como revalidar condições de acesso que tenham mudado após a liberação do script?

A identificação técnica da conta, verificação de privilégios e tratamento de códigos de erro pertencem às etapas posteriores.

## Impacto

Consolida a fronteira de autoridade: só há execução quando as regras da aplicação e as permissões do usuário dedicado a autorizarem, sem concessão autônoma de privilégios.

## Bloqueadora

**Sim, parcialmente resolvida.** A identidade executora está aprovada, mas a comprovação das permissões efetivas e o comportamento diante de alterações continuam pendentes em [OPEN-020](OPEN-020.md).

## Próxima ação

Manter [PCH-001](../PCH-001.md) e [NOBJ-001](../non-objectives/NOBJ-001.md) alinhados à identidade aprovada e definir com [OPEN-020](OPEN-020.md) as garantias de negação e rastreabilidade.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-020](OPEN-020.md)
- [OPEN-022](OPEN-022.md)
