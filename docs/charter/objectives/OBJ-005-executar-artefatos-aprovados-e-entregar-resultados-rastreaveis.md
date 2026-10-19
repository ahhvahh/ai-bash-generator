# OBJ-005 — Executar artefatos aprovados e entregar resultados rastreáveis

![Tipo: OBJ](../../assets/documentation-style/badges/badge-type-obj.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

**Evidência:** `DOCUMENTED` — decisões aprovadas pelo responsável pelo projeto; implementação não verificada.

## Motivação

Garantir que a geração produza um resultado operacional controlado e verificável, sem executar artefatos não autorizados.

## Resultado esperado

Artefatos Bash são registrados e liberados automaticamente apenas após a aprovação das validações obrigatórias. A execução usa uma conta de serviço dedicada, sujeita às regras da aplicação e às permissões efetivas do SO. O resultado, incluindo `stdout`, `stderr` e eventuais falhas, é registrado e recuperável pela aplicação solicitante.

## Critérios verificáveis

- Nenhum artefato reprovado ou de segurança indeterminada é liberado para execução.
- Artefatos liberados seguem para execução automática, sem aprovação humana individual adicional.
- A execução respeita a identidade dedicada e não eleva privilégios autonomamente.
- Saídas `stdout` e `stderr` são registradas até a conclusão, respeitadas as pendências de interrupção em [OPEN-021](../open-questions/OPEN-021-cancelamento-tempo-limite-e-falhas-operacionais.md).
- Rejeições e falhas registram motivo e são disponibilizadas à aplicação solicitante.

## Limites

Não especifica armazenamento, interfaces, transporte ou tecnologia do serviço. Os critérios completos de segurança e de interrupção permanecem em [OPEN-020](../open-questions/OPEN-020-garantias-de-validacao-antes-de-gerar-e-executar.md) e [OPEN-021](../open-questions/OPEN-021-cancelamento-tempo-limite-e-falhas-operacionais.md).

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-004](OBJ-004-revisar-independentemente-funcoes-e-corrigir-divergencias.md)
- [NOBJ-001](../non-objectives/NOBJ-001-nao-executar-alem-das-permissoes-concedidas-ao-usuario-do-servico.md)
- [OPEN-001](../open-questions/OPEN-001-criterios-mensuraveis-de-sucesso.md)
- [OPEN-020](../open-questions/OPEN-020-garantias-de-validacao-antes-de-gerar-e-executar.md)
- [OPEN-022](../open-questions/OPEN-022-geracao-versus-execucao-automatica-do-artefato.md)

## Execução automática do script composto e retorno à aplicação

**DOCUMENTED — refinamento funcional aprovado:** após composição verificável de [OBJ-006](OBJ-006-compor-funcoes-reutilizaveis-em-um-fluxo-bash-verificavel.md), montagem do script Bash pela aplicação responsável e conclusão de todas as validações obrigatórias, o serviço libera e executa automaticamente o artifact usando a conta dedicada, sem aprovação individual adicional. A execução pertence a uma etapa separada da busca no catálogo; nenhuma consulta de assinatura funcional autoriza nem inicia execução. O serviço registra resultados, status, `stdout`, `stderr` e razões de bloqueio/falha e entrega tais informações à aplicação que originou o pedido, conforme [OPEN-022](../open-questions/OPEN-022-geracao-versus-execucao-automatica-do-artefato.md). Cancelamento e falhas parciais continuam pendentes em [OPEN-021](../open-questions/OPEN-021-cancelamento-tempo-limite-e-falhas-operacionais.md).
