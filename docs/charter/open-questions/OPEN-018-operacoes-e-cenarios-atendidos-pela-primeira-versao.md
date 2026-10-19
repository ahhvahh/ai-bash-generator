# OPEN-018 — Operações e cenários atendidos pela primeira versão

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais operações locais e classes de solicitação devem integrar a V1 e quais devem ficar explicitamente fora dela?

## Contexto para refinamento

Foram considerados como cenários iniciais operações pontuais no sistema operacional: executar comandos permitidos, consultar diretórios e arquivos, obter contagens e consultar recursos de máquina e rede. A amplitude real do produto ainda precisa ser delimitada, pois disponibilidade de comandos não equivale a autorização para executá-los. A escolha do catálogo de funções e das integrações concretas pertence às etapas seguintes.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Quais operações precisam estar expressamente dentro da primeira versão?
- Que categorias devem ser excluídas ou depender de confirmação adicional?
- Como comprovar que os cenários escolhidos respeitam as permissões da conta de serviço?

## Impacto

Sem limite de produto, aceitação de geração e execução automática podem ter expectativas incompatíveis.

## Bloqueadora

Sim — delimitação de produto necessária ao gate de Charter.

## Próxima ação

Consolidar lista de capacidades-alvo por finalidade e propor OBJ/NOBJ específicos quando aplicável.

## Relações internas de Charter

- [PCH-001](../project-context/PCH-001-geracao-e-execucao-de-scripts-bash-com-permissoes-controladas.md)
- [OBJ-001](../objectives/OBJ-001-gerar-scripts-bash-a-partir-de-linguagem-natural.md)
- [NOBJ-001](../non-objectives/NOBJ-001-nao-executar-alem-das-permissoes-concedidas-ao-usuario-do-servico.md)
- [OPEN-020](OPEN-020-garantias-de-validacao-antes-de-gerar-e-executar.md)
