# Pendências documentais e gates

Estado consolidado após a adoção de tasks estruturadas, ABI JSON e composição determinística por functions.

## BLOCKED — decisões arquiteturais

| ID | Escopo bloqueado | Estado atual | Estado necessário | Informação ou decisão ausente | Dependências afetadas |
|---|---|---|---|---|---|
| ADR-0008 | Catálogo e busca | `refinement` | `refined` | Definir pinagem por `capability_version_id` e localização dos metadados versionáveis | DSG-0002, MOD-0002, CTR-0001, PST-0001 |
| ADR-0011 | Functions geradas | `refinement` | `refined` | Definir análise estrutural, namespace, top-level proibido e colisões | MOD-0003, MOD-0004, FLW-0001 |
| ADR-0012 | Segurança/policy | `refinement` | `refined` | Estruturar efeitos da capability e regra de autorização | DSG-0002, MOD-0004, CTR-0001 |
| ADR-0013 | Geração de capability | `refinement` | `refined` | Definir orçamento, limites e número de turnos para gerar uma FUNCTION ausente | MOD-0003, FLW-0001, FLW-0004 |
| ADR-0014 | Runtime de inferência | `refinement` | `refined` | Escolher modelo único na V1 ou lifecycle explícito de múltiplos modelos | DSG-0003, CTR-0003 |
| ADR-0015 | API externa | `refinement` | `refined` | Definir envelopes, correlação, erros, cancelamento, framing e limites | DSG-0003, CTR-0004, FLW-0005 |

## BLOCKED — desenho

- **DSG-0002 — Catálogo de capabilities**
  - estado atual: `backlog`;
  - estado necessário: `finalized`;
  - bloqueadores: ADR-0008 e ADR-0012.

- **DSG-0003 — Runtime do daemon**
  - estado atual: `backlog`;
  - estado necessário: `finalized`;
  - bloqueadores: ADR-0014 e ADR-0015, além das regras operacionais de concorrência/cancelamento.

## Pendências HIGH

1. schema Protobuf físico final para input lógico, output contract e conjunto de tasks/capabilities resolvidas;
2. tipagem de literais e política para captura escalar de `result_ref`;
3. taxonomia de códigos de saída das functions;
4. limite de concorrência do DAG e regra para selecionar tasks prontas;
5. buffering/materialização de resultados de branches paralelos até fan-in;
6. semântica de falha, cancelamento e cleanup quando uma branch paralela falhar;
7. manifesto de dependências do `BashArtifact`;
8. portabilidade `SELF_CONTAINED` versus `HOST_BOUND`;
9. validação em runtime de checksums de dependências externas;
10. ator, auditoria e operações administrativas de approve/activate/block/deprecate;
11. testes funcionais de capabilities e critério de promoção;
12. tratamento de prompt injection em resultados de MCP/tool;
13. backpressure, deadlines e propagação de cancelamento;
14. snapshot de configuração durante uma requisição;
15. estratégia de migrations e compatibilidade de schema PostgreSQL.

## Pendências MEDIUM

1. ranking e desempate determinísticos da busca;
2. canonicalização formal da fingerprint;
3. `risk_level` como enum/constraint;
4. validação explícita de `requested_filename` e separação do diretório de saída;
5. versionamento funcional de protocolo, pipeline e contrato de capability;
6. benchmark de representação na fronteira LLM, sem alterar a decisão de JSON como payload funcional.

## Decisões fechadas nesta revisão

- o normalizador descreve cada task por input lógico estruturado, instruction e output contract;
- contrato lógico foi separado de transporte;
- Protobuf/TextProto permanece no plano de controle;
- JSON UTF-8 é a ABI funcional entre functions;
- toda capability resolvida apresenta uma função Bash uniforme ao assembler;
- SCRIPT, APPLICATION e SERVICE ficam encapsulados pelo wrapper da capability;
- LLM não monta mais o script final;
- LLM gera FUNCTION somente quando a task não possui solução compatível;
- o Bash Output realiza assembly determinístico;
- tasks formam um DAG e tarefas independentes não devem ser serializadas artificialmente;
- fan-in estrutural é responsabilidade do Input Binder e não cria capability artificial.

## Critério para desenvolvimento

Nenhum item dependente dos ADRs, desenhos e especificações ainda em `refinement` ou `backlog` deve ser tratado como liberado apenas pela existência de texto documental.

Em especial, a execução paralela permanece **BLOCKED para implementação** até serem definidos limite de concorrência, armazenamento/buffering de resultados, falhas/cancelamento e cleanup.
