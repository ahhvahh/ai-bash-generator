# OPEN-020 — Garantias de validação antes de gerar e executar

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais garantias são obrigatórias para liberar automaticamente um script Bash à execução, impedindo operações não autorizadas ou cuja segurança não possa ser determinada?

## Contexto para refinamento

O sistema gera e registra scripts Bash para execução posterior por um serviço com identidade dedicada e permissões controladas.

A geração, a validação e a execução possuem responsabilidades distintas. A validade sintática de um script não comprova, isoladamente, sua segurança nem sua aderência à finalidade solicitada.

## Decisões funcionais aprovadas — 11/10/2026

1. **Liberação automática condicionada:** um script somente poderá ser liberado quando todas as validações obrigatórias tiverem sido aprovadas.

2. **Dupla autorização:** a execução deverá respeitar simultaneamente as regras de segurança da aplicação e as permissões efetivas do sistema operacional.

3. **Operações potencialmente destrutivas:** não serão proibidas indiscriminadamente, mas somente poderão ser autorizadas quando cumprirem ambas as condições de segurança.

4. **Segurança indeterminada:** a ausência de evidência suficiente para determinar a segurança do script deverá impedir automaticamente sua liberação.

5. **Tratamento de reprovação:** uma validação reprovada ou inconclusiva deverá produzir um resultado de falha, registrar o motivo e disponibilizá-lo à aplicação solicitante.

6. **Ausência de elevação de privilégios:** o serviço executor não poderá ampliar automaticamente suas permissões para executar um script.

A aprovação de um script pela aplicação não substitui a autorização efetiva do sistema operacional. Da mesma forma, a existência de permissões no sistema operacional não substitui as regras de segurança da aplicação.

## Critérios funcionais verificáveis

- Script aprovado em todas as validações obrigatórias: elegível para liberação automática.
- Script reprovado em qualquer validação obrigatória: liberação bloqueada.
- Segurança não determinável: liberação bloqueada.
- Operação não autorizada pela aplicação: execução bloqueada, ainda que permitida pelo sistema operacional.
- Operação não autorizada pelo sistema operacional: execução impedida, ainda que aprovada pela aplicação.
- Toda rejeição deverá ter um motivo registrado e recuperável pela aplicação solicitante.
- Um script não liberado não deverá ser enviado ao serviço para execução.

O cumprimento dessas regras não pressupõe que seja possível prever todos os efeitos de uma execução por análise estática.

## Pontos ainda pendentes de refinamento

- Definição do conjunto mínimo de verificações obrigatórias: sintaxe, finalidade, entradas, dependências, permissões e análise de segurança.
- Critérios para classificar uma operação como permitida, proibida ou de segurança indeterminada.
- Evidências mínimas exigidas para considerar cada validação aprovada.
- Critérios de teste para comprovar o comportamento de bloqueio.
- Tratamento de alterações nas permissões entre a liberação e a execução.

Os mecanismos de análise, contratos, modelos de persistência e tecnologias de validação deverão ser detalhados nas etapas posteriores.

## Impacto

Estabelece um comportamento de negação por padrão quando não houver segurança demonstrável, reduzindo o risco de liberação de scripts indevidos.

## Bloqueadora

**Sim, parcialmente resolvida.** A política de autorização e bloqueio foi aprovada. A definição completa das validações e dos critérios verificáveis ainda depende de refinamento.

## Próxima ação

Definir e aprovar as verificações obrigatórias e os respectivos critérios de aceitação. Após isso, reavaliar a condição bloqueadora e o gate Charter → Scope.

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-001](../objectives/OBJ-001-gerar-scripts-bash-a-partir-de-linguagem-natural.md)
- [NOBJ-001](../non-objectives/NOBJ-001-nao-executar-alem-das-permissoes-concedidas-ao-usuario-do-servico.md)
- [OPEN-001](OPEN-001-criterios-mensuraveis-de-sucesso.md)
- [OPEN-013](OPEN-013-identidade-e-privilegios-de-execucao.md)
- [OPEN-021](OPEN-021-cancelamento-tempo-limite-e-falhas-operacionais.md)
- [OPEN-022](OPEN-022-geracao-versus-execucao-automatica-do-artefato.md)

## Revisão funcional independente antes da liberação

**DOCUMENTED:** uma LLM revisora, distinta da responsabilidade de geração, deverá confrontar a função candidata com a tarefa e a solicitação original, emitindo parecer fundamentado. A reprovação corrigível poderá originar nova geração dentro dos limites de [OPEN-014](OPEN-014-orcamento-de-processamento-e-recuperacao.md); a reprovação não corrigível, a inconclusão ou o esgotamento do limite impedem liberação e exigem falha registrada. A composição final também deverá ser avaliada quanto à intenção original, conforme [OBJ-004](../objectives/OBJ-004-revisar-independentemente-funcoes-e-corrigir-divergencias.md).

A revisão semântica **não prova segurança** e não substitui validação sintática, regras da aplicação, permissões efetivas do SO ou outras verificações obrigatórias. O conjunto completo e as evidências dessas verificações continuam pendentes neste documento.
