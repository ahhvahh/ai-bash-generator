# Sessão e orçamento de contexto do gerador

![ADR](https://img.shields.io/badge/ADR-ADR--0013-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

O gerador deixou de compor o script completo. Sua responsabilidade é produzir uma FUNCTION para uma task que não possua capability compatível.

Ainda assim, uma geração pode acumular contrato da task, restrições, resultados de tools e tentativas de correção.

## Problema

Sem orçamento explícito, uma sessão de geração de capability pode exceder o contexto disponível ou acumular resultados de tools desnecessários.

## Restrições

- hardware de referência é limitado;
- o contexto deve ser restrito à task não resolvida;
- tool loop precisa de número máximo de turnos e resultados limitados;
- functions já resolvidas de outras tasks não devem ser reenviadas apenas para composição.

## Opções consideradas

### Reenviar contexto completo da requisição

Mantém informação ampla, porém desperdiça contexto com tasks já resolvidas e responsabilidades que pertencem ao assembler.

### Sessão limitada à capability ausente

Mantém task, contratos, restrições, tools autorizadas e issues de validação necessárias para produzir uma única FUNCTION.

## Decisão

Em refinamento. A sessão deve ser limitada à task não resolvida, mas limites numéricos, compactação e número máximo de turnos ainda não foram definidos.

## Justificativa

A nova responsabilidade do gerador permite reduzir significativamente o contexto sem perder informação necessária à solução da task.

## Consequências

MOD-0003 permanece bloqueado para refinamento final até que os limites sejam definidos.

## Dependências

- [ADR-0001](../pipeline/pipeline-hibrido.md)

## Critérios de validação

- definir limites configuráveis e defaults;
- definir estimativa de tokens;
- definir comportamento ao exceder orçamento;
- impedir envio desnecessário do script completo ou de functions de tasks já resolvidas.
