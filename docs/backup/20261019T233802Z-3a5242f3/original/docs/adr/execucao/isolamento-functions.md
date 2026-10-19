# Isolamento de functions geradas

![ADR](https://img.shields.io/badge/ADR-ADR--0011-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refined-0969da?style=flat-square)
![Version](https://img.shields.io/badge/Version-1-6e7781?style=flat-square)

## Contexto

Na V1, as capabilities geradas serão usadas para processamentos pontuais de sistema.

Exemplos de escopo inicial:

- executar um comando;
- listar ou consultar diretórios;
- contar arquivos;
- consultar uso de CPU;
- consultar uso de memória;
- consultar armazenamento;
- consultar informações de rede;
- executar aplicações pontuais disponíveis no ambiente.

Comandos e funções mais elaborados podem ser adicionados futuramente conforme o projeto evoluir.

## Problema

O artifact pode incorporar várias functions. Se uma capability puder declarar helpers, globals ou código executável fora da function principal, símbolos podem colidir e carregar uma definição pode produzir efeitos inesperados.

Para o escopo simples da V1, essa complexidade não é necessária.

## Restrições

- cada capability gerada representa uma única operação pontual;
- cada capability gerada contém exatamente uma FUNCTION;
- não são permitidas functions auxiliares geradas;
- não são permitidas variáveis globais geradas;
- não é permitido código executável no top-level;
- o corpo da FUNCTION pode executar os comandos necessários à operação;
- a FUNCTION continua obedecendo à ABI JSON por stdin/stdout;
- a execução respeita as permissões do usuário/processo e do ambiente conforme ADR-0012.

## Decisão

Na V1, uma capability gerada possui **uma única FUNCTION Bash isolada**.

O nome da FUNCTION é atribuído e controlado pela aplicação, não pela LLM. O conjunto materializado deve possuir nomes únicos para todas as functions incorporadas.

A saída do gerador deve conter somente a definição dessa FUNCTION.

São proibidos:

- helpers adicionais;
- globals;
- aliases;
- comandos executáveis fora da FUNCTION;
- inicialização top-level;
- múltiplas definições de function no mesmo source.

O Validator realiza validação estrutural do source Bash antes da materialização. A validação precisa identificar a estrutura sintática; regex isolada não é considerada suficiente.

A escolha da biblioteca/parser concreto é detalhe de implementação desde que permita verificar deterministicamente as regras acima.

## Evolução futura

Quando o projeto precisar de capabilities mais elaboradas, este ADR pode ser reaberto para permitir helpers, namespaces compostos ou outras estruturas.

Essa evolução não deve ampliar implicitamente a V1.

## Justificativa

O escopo atual não precisa de um sistema complexo de namespaces ou reescrita de símbolos.

Restringir cada capability a uma única FUNCTION elimina a principal fonte de colisões e mantém a validação objetiva.

## Consequências

- o gerador produz somente uma definição de function por capability;
- o nome é controlado pela aplicação;
- helpers e globals ficam fora da V1;
- o Validator rejeita sources com estruturas adicionais;
- o assembler incorpora functions já isoladas e identificadas;
- operações mais complexas exigirão nova decisão ou refinamento desta regra.

## Dependências

- [ADR-0007](../geracao/capabilities-geradas.md)
- [ADR-0012](../seguranca/efeitos-capabilities.md)

## Critérios de validação

- existe exatamente uma definição de FUNCTION;
- não existe comando executável no top-level;
- não existem helpers adicionais;
- não existem globals;
- o nome usado no artifact é controlado pela aplicação e não colide com outra function;
- o source é sintaticamente válido em Bash;
- a estrutura é verificada por análise sintática adequada, não somente por regex.
