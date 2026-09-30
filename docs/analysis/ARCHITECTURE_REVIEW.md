# Revisão de Arquitetura

Esta revisão analisa o pipeline atual do `ai-bash-gen` antes da implementação.

O objetivo é identificar pontos que podem causar falha de execução, inconsistência de dados, comportamento imprevisível do LLM ou dificuldade de evolução.

Os diagramas de sequência estão em [../pipeline/SEQUENCE_DIAGRAMS.md](../pipeline/SEQUENCE_DIAGRAMS.md).

## Resumo

Foram identificados problemas que devem ser resolvidos antes ou durante a primeira implementação.

Classificação:

```text
BLOCKER  impede implementar o fluxo de forma confiável
HIGH     pode causar erro funcional, segurança ou inconsistência
MEDIUM   afeta desempenho, manutenção ou previsibilidade
LOW      melhoria de organização/evolução
```

## BLOCKER-01 — Não existe ABI para resultados entre funções Bash

A `NormalizedRequest` define:

```text
function A -> resultList -> function B
```

mas ainda não está definido como `resultList` existe em tempo de execução.

Uma tabela não pode ser passada entre funções Bash apenas pelo conceito `result_ref`.

É necessário definir um ABI de dados.

Exemplos possíveis:

- stdout/stdin;
- JSON Lines;
- TSV;
- NUL-delimited records;
- arquivo temporário;
- file descriptor.

### Risco

Duas capabilities podem declarar:

```text
output: table
input: table
```

e ainda assim serem incompatíveis na prática.

### Proposta

Definir um formato canônico inicial.

Exemplo:

```text
scalar       -> stdout textual
path         -> stdout textual, uma linha
list<path>   -> NUL-delimited
table        -> JSON Lines
binary/file  -> path para arquivo
```

O contrato precisa declarar não apenas o tipo lógico, mas a codificação de transporte.

---

## BLOCKER-02 — Duas fontes de verdade no GenerationResult

Hoje:

```proto
message GenerationResult {
  repeated CapabilityCall calls = 2;
  repeated GeneratedCapability generated_capabilities = 3;
  string script = 4;
}
```

O LLM pode produzir:

```text
calls = A -> B -> C
```

mas escrever um `script` que faça outra coisa.

Não está definido qual deles vence.

### Proposta

O LLM deve produzir o plano estruturado e as novas implementações.

O arquivo final deve ser montado deterministicamente pelo `bash-output`.

Fluxo recomendado:

```text
GenerationPlan
      |
      v
validation
      |
      v
deterministic assembler
      |
      v
BashArtifact
```

Remover `script` como fonte canônica ou tratá-lo apenas como campo derivado.

---

## BLOCKER-03 — get_capability não possui protocolo de turnos

A documentação diz que o `bash-generator` pode solicitar:

```text
get_capability(id)
```

durante sua decisão.

Porém o contrato atual só possui:

```text
GenerationRequest -> GenerationResult
```

Não há mensagem que represente:

```text
LLM:
"preciso dos detalhes da capability X"

aplicação:
"estes são os detalhes"

LLM:
"agora continuo"
```

### Risco

A implementação pode acabar dependendo de comportamento específico do tool calling do modelo ou do llama.cpp sem um contrato interno estável.

### Proposta

Formalizar um loop:

```text
GeneratorTurnRequest
GeneratorToolRequest
GeneratorToolResponse
GeneratorFinalResult
```

ou definir explicitamente que o MCP/tool loop pertence ao `ai-bash-gen` e documentar o envelope utilizado.

---

## BLOCKER-04 — Sistema de tipos insuficiente para composição

Campos como:

```proto
string type
string input_contract
string output_contract
```

não permitem validação forte.

Duas capabilities podem declarar:

```text
type = "table"
```

mas uma produzir:

```text
name,size,type
```

e outra esperar:

```text
email,date,subject
```

### Proposta

Criar tipos estruturados.

Exemplo conceitual:

```text
DataType
RecordSchema
FieldSchema
CollectionType
Encoding
```

Compatibilidade deve ser calculada pela aplicação, não pelo texto produzido pelo LLM.

---

## BLOCKER-05 — Versionamento do catálogo não está consistente

A documentação prevê versões, mas:

```sql
capability_detail.capability_id PRIMARY KEY
version SMALLINT
```

permite apenas uma linha de detalhe por capability.

O Protobuf também solicita:

```text
get_capability(id)
```

sem versão.

### Risco

Uma atualização muda silenciosamente uma capability que já foi usada em scripts anteriores.

### Proposta

Separar:

```text
capability
    identidade lógica

capability_version
    versão imutável
```

Exemplo:

```text
capability
  id
  capability_key
  active_version_id

capability_version
  id
  capability_id
  version
  implementation
  contracts
  checksum
```

`get_capability` deve devolver o ID/version da definição efetivamente utilizada.

---

## BLOCKER-06 — script/application/service não possuem contrato de invocação no Protobuf

`CapabilityType` permite:

```text
FUNCTION
SCRIPT
APPLICATION
SERVICE
```

mas `CapabilityDefinition` contém principalmente:

```text
function_name
source
```

Não há representação suficiente para:

- caminho do executável;
- argumentos;
- stdin/stdout;
- Unix Socket;
- endpoint de serviço;
- timeout;
- ambiente necessário.

### Proposta

Usar `oneof implementation`:

```text
function
script
application
service
```

cada um com contrato próprio.

---

## BLOCKER-07 — Capability candidata pode aparecer na pesquisa antes de ser aprovada

O estado está em `capability_detail.status`, enquanto `search_capabilities` consulta apenas:

```sql
FROM capability
WHERE enabled = TRUE
```

`capability.enabled` possui default `TRUE`.

Uma capability gerada como `candidate` pode ser pesquisável se o insert não controlar explicitamente esse campo.

### Proposta

A pesquisa deve exigir estado ativo de forma estrutural.

Por exemplo:

```text
capability.active_version_id IS NOT NULL
```

ou manter `status` na tabela/index pesquisado.

Nunca depender apenas de convenção no código de insert.

---

## BLOCKER-08 — Persistência e criação do arquivo não possuem fronteira transacional

Hoje o `bash-output` pode:

1. persistir nova capability;
2. criar arquivo.

Banco PostgreSQL e filesystem não compartilham uma transação.

Exemplo de falha:

```text
INSERT capability OK
gravação do arquivo FAIL
```

ou:

```text
arquivo criado OK
INSERT capability FAIL
```

### Proposta

Separar dois resultados independentes:

```text
validated generation
      |
      +--> publish capability (idempotente)
      |
      +--> materialize BashArtifact
```

Cada operação deve ser repetível com um `request_id`/idempotency key.

---

## HIGH-01 — Sem representação adequada de informação ausente

O normalizador recebe a regra:

```text
não inventar valores
```

mas `NormalizedRequest` não possui um contrato claro para:

```text
required input is missing
```

O status `MISSING_INFORMATION` só aparece no `GenerationResult`.

### Proposta

Adicionar ao resultado da normalização:

```text
missing_inputs[]
normalization_status
```

e interromper o pipeline antes da busca quando faltar informação essencial.

---

## HIGH-02 — depends_on e result_ref podem divergir

Hoje existem dois mecanismos de dependência:

```text
depends_on
result_ref
```

Pode ocorrer:

```text
result_ref = resultList
depends_on = outra_tarefa
```

### Proposta

Definir:

- `result_ref` cria dependência de dados automaticamente;
- `depends_on` existe apenas para dependência de controle sem troca de dados.

A validação deve derivar o DAG final e detectar inconsistências.

---

## HIGH-03 — Telemetria não identifica a versão acessada

`capability_usage` guarda apenas:

```text
capability_id
requested_at
```

Depois de uma atualização não será possível saber qual implementação foi entregue ao LLM.

### Proposta

O append mínimo deveria apontar para versão imutável:

```text
capability_version_id
requested_at
```

Opcionalmente incluir `request_id` para auditoria sem aumentar muito o registro.

---

## HIGH-04 — Validação Bash apenas sintática é insuficiente

`bash -n` detecta sintaxe, mas não detecta:

- variável não inicializada;
- quoting incorreto;
- comando inexistente;
- dependência não declarada;
- uso perigoso de `eval`;
- globbing inesperado;
- erros comuns identificáveis estaticamente.

### Proposta

Pipeline de validação:

```text
protobuf validation
      |
      v
contract validation
      |
      v
policy validation
      |
      v
bash -n
      |
      v
ShellCheck, quando disponível
      |
      v
dependency validation
```

Execução real continua proibida na primeira versão.

---

## HIGH-05 — Capabilities geradas pelo LLM precisam de nível de confiança

Uma função criada em uma requisição pode ser reutilizada por muitas outras no futuro.

Um erro deixa de afetar uma requisição e passa a contaminar o catálogo.

### Proposta

Estados:

```text
candidate
validated
approved
active
deprecated
blocked
```

Para operações de maior risco, `validated` não deve significar automaticamente `active`.

---

## HIGH-06 — Concorrência pode criar capabilities equivalentes

Duas requisições simultâneas podem:

1. pesquisar;
2. não encontrar;
3. gerar a mesma funcionalidade;
4. deduplicar antes de qualquer insert;
5. inserir duas capabilities.

### Proposta

Usar uma assinatura/fingerprint canônica e constraint única ou lock transacional durante publicação.

---

## HIGH-07 — Ferramentas de geração e ferramentas de runtime estão misturadas

O Gmail MCP pode fornecer informação durante a geração.

Isso não significa que o script Bash gerado consiga consultar Gmail quando for executado depois.

Existem dois conceitos diferentes:

```text
generation-time tool
runtime capability
```

Eles precisam ser separados.

Exemplo:

```text
"leia meu último e-mail agora e gere um relatório"
    generation-time

"gere um script que consulte novos e-mails amanhã"
    runtime
```

O segundo caso exige uma capability invocável pelo script.

---

## HIGH-08 — Propriedade dos MCPs está contraditória

O README ainda apresenta MCPs abaixo do `llama-server`.

Outros documentos colocam controle e autorização no `ai-bash-gen`.

Para isolamento, auditoria e Gmail, a propriedade precisa ser inequívoca.

### Proposta

```text
LLM/llama-server
      |
      | tool request
      v
ai-bash-gen Tool Orchestrator
      |
      +--> Capability Catalog
      +--> Google Mail
```

O `llama-server` deve permanecer motor de inferência, não autoridade de acesso.

---

## HIGH-09 — Semântica de caminhos com ~ pode produzir Bash incorreto

A normalização preserva:

```text
~/ambiente
```

mas:

```bash
some_function "~/ambiente"
```

não expande `~` no Bash.

### Proposta

Manter o valor semântico separado de sua representação shell.

O materializador deve converter caminhos de home de maneira segura, por exemplo:

```bash
"$HOME/ambiente"
```

sem alterar o dado original dentro da `NormalizedRequest`.

---

## MEDIUM-01 — Número de candidatos pode crescer rapidamente

Com:

```text
5 candidatos compostos
+
5 candidatos por tarefa
```

uma requisição com 10 tarefas pode entregar até 55 candidatos ao gerador.

### Proposta

Além do limite por busca, definir:

```text
global_candidate_budget
max_candidates_per_task
max_capability_details
```

e deduplicar IDs globalmente.

---

## MEDIUM-02 — Repetição de get_capability

O mesmo ID pode aparecer como candidato composto e em várias tarefas.

Sem cache, cada consulta pode:

- ler novamente o PostgreSQL;
- aumentar telemetria várias vezes;
- consumir tokens novamente.

### Proposta

Cache por requisição:

```text
capability_version_id -> CapabilityDefinition
```

Uma definição já carregada não deve gerar novo append dentro da mesma requisição, salvo política explícita.

---

## MEDIUM-03 — TextProto não garante economia de tokens

Protobuf binário economiza IPC.

TextProto é estruturado, porém pode ser mais verboso que JSON compacto em alguns tokenizers.

### Proposta

Não assumir economia.

Criar benchmark usando o tokenizer do modelo:

```text
JSON compacto
TextProto
formato compacto específico
```

e medir:

- tokens;
- taxa de parsing;
- taxa de respostas válidas;
- latência.

A decisão deve considerar robustez e não apenas bytes.

---

## MEDIUM-04 — Prompt duplicado em AGENTS.md e nos documentos de pipeline

Existem prompts/configurações em:

```text
docs/AGENTS.md
docs/pipeline/01_REQUEST_NORMALIZER.md
docs/pipeline/04_BASH_GENERATOR.md
```

Eles podem divergir.

### Proposta

Definir uma única fonte canônica para prompt.

`AGENTS.md` deve referenciar o prompt da etapa, não duplicá-lo integralmente.

---

## MEDIUM-05 — FTS textual não valida contrato

Full Text Search pode localizar semanticamente um candidato que não atende campos ou tipos.

### Proposta

Busca em duas fases:

```text
1. candidate retrieval
   FTS / intent

2. deterministic pruning
   input/output compatibility
   capability type
   platform
   policy
```

Somente depois os poucos candidatos sobreviventes são entregues ao LLM.

---

## Ordem recomendada de correção

Antes da implementação principal:

1. definir ABI dos resultados;
2. eliminar dupla fonte de verdade da geração;
3. formalizar tool loop;
4. criar tipo/contrato estruturado;
5. corrigir versionamento;
6. definir implementação por tipo de capability;
7. garantir que somente versões ativas sejam pesquisáveis;
8. definir publicação idempotente;
9. representar missing information;
10. separar geração-time e runtime tools.

Depois:

11. endurecer validação Bash;
12. limitar candidatos globalmente;
13. cachear capability details;
14. benchmark de TextProto;
15. consolidar prompts.
