# Pendências documentais e gates

Estado consolidado após a adoção de tasks estruturadas, ABI JSON e composição determinística por functions.

## BLOCKED — decisões arquiteturais

| ID | Escopo bloqueado | Estado atual | Estado necessário | Informação ou decisão ausente | Dependências afetadas |
|---|---|---|---|---|---|
| ADR-0013 | Geração de capability | `refinement` | `refined` | Definir orçamento, limites e número de turnos para gerar uma FUNCTION ausente | MOD-0003, FLW-0001, FLW-0004 |
| ADR-0014 | Runtime de inferência | `refinement` | `refined` | Escolher modelo único na V1 ou lifecycle explícito de múltiplos modelos | DSG-0003, CTR-0003 |
| ADR-0015 | API externa | `refinement` | `refined` | Definir envelopes, correlação, erros, cancelamento, framing e limites | DSG-0003, CTR-0004, FLW-0005 |

## BLOCKED — desenho

- **DSG-0003 — Runtime do daemon**
  - estado atual: `backlog`;
  - estado necessário: `finalized`;
  - bloqueadores: ADR-0014 e ADR-0015, além das regras operacionais de concorrência/cancelamento.

## Pendências HIGH

1. schema Protobuf físico final para input lógico, output contract e conjunto de tasks/capabilities resolvidas;
2. tipagem de literais e política para captura escalar de `result_ref`;
3. taxonomia de códigos de saída das functions;
4. regra para selecionar tasks prontas quando houver mais candidatas do que vagas;
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

1. canonicalização formal da fingerprint;
2. `risk_level` como enum/constraint;
3. validação explícita de `requested_filename` e separação do diretório de saída;
4. versionamento funcional de protocolo, pipeline e contrato de capability;
5. benchmark de representação na fronteira LLM, sem alterar a decisão de JSON como payload funcional.

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
- fan-in estrutural é responsabilidade do Input Binder e não cria capability artificial;
- Capability Search usa matching exato de input, output e propósito;
- ausência de correspondência exata encaminha a task para geração de nova FUNCTION;
- a busca retorna o `capability_version_id` da versão ativa mais recente e o pipeline mantém essa pinagem;
- melhorias de performance/implementação de uma mesma função são novas versões imutáveis da mesma capability;
- autorização operacional pertence ao usuário/processo e ao ambiente que executam o `BashArtifact`;
- o catálogo e a LLM não concedem privilégios;
- aplicações externas somente podem ser usadas quando estiverem disponíveis e acessíveis ao executor;
- DSG-0002 foi finalizado após o fechamento dessa fronteira de autorização;
- na V1, cada capability gerada contém uma única FUNCTION para processamento pontual;
- helpers, globals, múltiplas functions e código executável top-level ficam proibidos na V1;
- o nome da FUNCTION é controlado pela aplicação e a estrutura é validada antes da materialização;
- na V1, cada execução do `BashArtifact` permite no máximo quatro tasks simultâneas.

## Critério para desenvolvimento

Nenhum item dependente dos ADRs, desenhos e especificações ainda em `refinement` ou `backlog` deve ser tratado como liberado apenas pela existência de texto documental.

Em especial, a execução paralela permanece **BLOCKED para implementação completa** apesar do limite de quatro já estar definido; ainda faltam regra de seleção entre tasks prontas, armazenamento/buffering de resultados, falhas/cancelamento e cleanup.
