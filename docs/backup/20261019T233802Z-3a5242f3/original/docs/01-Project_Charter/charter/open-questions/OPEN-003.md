# OPEN-003 — Contratos estruturados na interação com inferência

![Tipo: OPEN](../../assets/documentation-style/badges/badge-type-open.svg) ![Status: refinement](../../assets/documentation-style/badges/badge-status-refinement.svg) ![Versão: v1](../../assets/documentation-style/badges/badge-version-v1.svg)

## Pergunta

Quais garantias de clareza, validade e interoperabilidade das solicitações são indispensáveis, independentemente do formato de contrato?

## Contexto para refinamento

A troca de informações entre etapas pode exigir conteúdo estruturado, validável e compreensível. Foram avaliadas representações distintas para comunicação entre componentes e para instruções de modelos de inferência. A escolha de codificação não altera, por si só, a necessidade do produto de preservar significado e integridade.

O conteúdo registra alternativas para reavaliação, não uma decisão técnica aprovada nem comprovação de implementação.

## Pontos para deliberação

- Que garantias de clareza, validação e integridade são exigidas das informações processadas?
- O produto exige interoperabilidade entre mecanismos de inferência diferentes?
- A comparação entre alternativas precisa ser baseada em testes de custo, qualidade e compatibilidade?

## Impacto

Define a necessidade de resultados interpretáveis e verificáveis sem fixar serialização no Charter.

## Bloqueadora

Não — formato e schema são decisões de Scope/Implementation.

## Próxima ação

Refinar o resultado verificável de interoperabilidade, sem transportar formatos físicos para Charter.

## Relações internas de Charter

- [PCH-001](../PCH-001.md)
- [OBJ-001](../objectives/OBJ-001.md)
- [CON-001](../constraints/CON-001.md)

## Candidatos de representação compacta — ilustração não normativa

**PROPOSED para experimentação:** testar JSON compacto com campos fixos e tuplas posicionais, reduzindo repetição para modelos menores. A escolha de codificação, schema, versão e limites de tamanho permanece pendente de Scope/Implementation.

- A planejadora em [OBJ-003](../objectives/OBJ-003.md) recebe solicitação original e retorna `status`, `tasks` e, se necessário, `questions`.
- Para a **busca de contrato**, a tarefa deve representar entrada, saída e propósito do algoritmo, sem valores de instâncias ou parâmetros; nomes e serialização físicos permanecem pendentes.
- Referências entre tarefas e coleções tipadas são necessárias em nível lógico; detalhes de codificação ficam para Scope.
- A geradora em [OBJ-001](../objectives/OBJ-001.md) recebe uma tarefa de cada vez; a revisora em [OBJ-004](../objectives/OBJ-004.md) recebe solicitação, tarefa e candidata, retornando parecer.

```json
{
  "id": "T1",
  "input": {
    "object": "filesystem.directory"
  },
  "output": {
    "object": "filesystem.entry[]"
  },
  "process": "Extrair metadados dos itens do diretório",
  "depends_on": []
}
```

**PENDING —** definir representação física de coleções, referências, passagem de parâmetros e versão do contrato; comparar tokens, latência, precisão e compatibilidade entre modelos. Os critérios de igualdade exata de [OBJ-002](../objectives/OBJ-002.md) continuam independentes dos valores concretos.

## Separação entre consulta abstrata e parâmetros de runtime

**DOCUMENTED como requisito funcional:** a descoberta de funções deve utilizar **contrato lógico de entrada, contrato lógico de saída e proposta de algoritmo/propósito**, sem receber nem avaliar valores concretos de parâmetros. A etapa de busca não coleta dados do SO, não executa funções e não infere execução a partir de assinatura. O normalizador de [OBJ-003](../objectives/OBJ-003.md) produz essas descrições; [OBJ-002](../objectives/OBJ-002.md) aplica correspondência exata; [OBJ-006](../objectives/OBJ-006.md) organiza funções recuperadas.

**Exemplo ilustrativo de contrato abstrato para experimentação, não normativo:**

```json
{
  "id": "T1",
  "input": {"object": "filesystem.directory"},
  "output": {"object": "filesystem.entry[]"},
  "process": "Extrair metadados dos itens do diretório",
  "depends_on": []
}
```

Os exemplos desta questão são **candidatos abstratos**, não instâncias ou valores de execução. **PENDING —** contrato físico e os tipos/formatos de transporte devem ser resolvidos em Scope. Não há decisão de substituir qualquer esquema técnico por este exemplo.
