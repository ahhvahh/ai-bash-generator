# NOBJ-001 — Não executar além das permissões concedidas ao usuário do serviço

![Tipo: NOBJ](../../assets/documentation-style/badges/badge-type-nobj.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**Evidência:** `DOCUMENTED` — decisão do responsável pelo projeto em 11/10/2026, substituindo a exclusão anterior de execução automática.

## Exclusão

O projeto não deve contornar nem ampliar automaticamente as permissões concedidas à conta de serviço no sistema operacional.

## Justificativa

Os scripts serão executados automaticamente no próprio SO por um serviço com usuário dedicado. Essa conta será criada na configuração do ambiente, e suas permissões e associações a grupos serão definidas pelo usuário responsável pela administração.

## Efeito sobre expectativas

A execução automática faz parte da finalidade do projeto. Seu alcance será determinado pelas permissões efetivas da conta de serviço, incluindo seus grupos de acesso e demais restrições do SO. A identidade do solicitante não substitui a conta usada para executar os scripts.

## Condição de revisão

Qualquer ampliação do alcance depende de alteração explícita das permissões pelo administrador, sem concessão autônoma de privilégios pelo serviço.
