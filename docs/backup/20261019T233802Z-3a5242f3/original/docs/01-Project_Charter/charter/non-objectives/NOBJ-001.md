# NOBJ-001 — Não executar além das permissões concedidas ao usuário do serviço

![Tipo: NOBJ](../../assets/documentation-style/badges/badge-type-nobj.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**Evidência:** `DOCUMENTED` — decisão do responsável pelo projeto em 11/10/2026, substituindo a exclusão anterior de execução automática.

## Exclusão

O projeto não deve contornar nem ampliar automaticamente as permissões concedidas à conta de serviço no sistema operacional.

A existência de permissões suficientes no sistema operacional não autoriza, por si só, a execução. Scripts reprovados pelas regras da aplicação ou cuja segurança não puder ser determinada não deverão ser liberados, mesmo quando a conta executora possuir permissão para realizar a operação.

## Justificativa

Os scripts serão executados automaticamente no próprio SO por um serviço com usuário dedicado, mas **somente após registro e liberação automática condicionada à aprovação de todas as validações obrigatórias**. A conta será criada na configuração do ambiente, e suas permissões e associações a grupos serão definidas pelo administrador. A liberação também depende das regras de segurança da aplicação, conforme [OPEN-020](../open-questions/OPEN-020.md).

## Efeito sobre expectativas

A execução automática integra a finalidade do produto, mas não implica execução irrestrita. Operações potencialmente destrutivas podem ser autorizadas somente quando satisfizerem, simultaneamente, as regras de segurança da aplicação e as permissões efetivas do SO. Uma avaliação de segurança reprovada ou indeterminada bloqueia a liberação, registra o motivo e devolve a falha ao solicitante. A identidade de quem fez a requisição não substitui a conta dedicada que executa os scripts.

## Condição de revisão

Qualquer ampliação do alcance depende de alteração explícita das permissões pelo administrador, sem concessão autônoma de privilégios pelo serviço.
