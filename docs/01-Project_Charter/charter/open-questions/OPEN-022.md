# OPEN-022 — Geração versus execução automática do artefato

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Após o registro de um script gerado, em que condições ocorre a liberação automática e como o resultado da execução chega à aplicação solicitante?

## Contexto para refinamento

A finalidade aprovada inclui geração, validação, registro, execução automática e entrega dos resultados. O serviço executor utiliza uma conta dedicada com permissões controladas, conforme [NOBJ-001](../non-objectives/NOBJ-001.md).

A aplicação registra o script produzido para execução posterior. As saídas da execução são registradas separadamente para consulta e devolução ao cliente final. O desenho físico das tabelas e das interfaces não é definido no Charter.

## Pontos para deliberação

**Decisões funcionais aprovadas — 11/10/2026:**

1. Após a geração, o script Bash é registrado para posterior execução por um serviço.
2. Sua **liberação é automática somente após a aprovação de todas as validações obrigatórias**, conforme [OPEN-020](OPEN-020.md); não é exigida aprovação humana individual para um script validado.
3. Uma vez registrado e liberado, o serviço inicia automaticamente a execução com a identidade dedicada e as permissões efetivas definidas pelo administrador do SO.
4. A execução produz registros dos resultados de `stdout` e `stderr` até sua finalização, em registro distinto daquele utilizado para o script.
5. A aplicação que iniciou o processamento recupera os resultados registrados e os devolve ao cliente final.
6. Se qualquer validação obrigatória for reprovada ou inconclusiva, o script **não é liberado**; a falha e seu motivo ficam registrados e são devolvidos ao solicitante.

**Permanecem em refinamento:** condições concretas das verificações de segurança e liberação ([OPEN-020](OPEN-020.md)); comportamento de timeout, cancelamento e falhas parciais ([OPEN-021](OPEN-021.md)); detalhamento de contratos, estados, tabelas e transporte nas etapas seguintes.

## Impacto

Confirma a execução automática condicionada à validação, a separação funcional entre registro do script e resultados e o retorno completo de `stdout` e `stderr` ao solicitante. O detalhamento técnico permanece posterior ao Charter.

## Bloqueadora

**Sim, parcialmente resolvida.** O acionamento automático e o retorno dos resultados estão aprovados. A liberação segura depende dos critérios ainda pendentes em [OPEN-020](OPEN-020.md); cancelamento e tratamento de falhas dependem de [OPEN-021](OPEN-021.md).

## Próxima ação

Consolidar o fluxo funcional em [PCH-001](../PCH-001.md), detalhar os critérios mínimos de liberação em [OPEN-020](OPEN-020.md) e tratar as garantias de interrupção em [OPEN-021](OPEN-021.md). Preservar o gate bloqueado até as pendências pertinentes serem resolvidas.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [NOBJ-001](../non-objectives/NOBJ-001.md)
- [OPEN-013](OPEN-013.md)
- [OPEN-020](OPEN-020.md)
- [OPEN-021](OPEN-021.md)
