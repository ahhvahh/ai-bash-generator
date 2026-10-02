# Pendências documentais e gates

Estado consolidado após a adequação ao ADP 1.0.

## BLOCKED — decisões arquiteturais

| ID | Escopo bloqueado | Estado atual | Estado necessário | Informação ou decisão ausente | Dependências afetadas |
|---|---|---|---|---|---|
| ADR-0008 | Catálogo e busca | `refinement` | `refined` | Definir pinagem por `capability_version_id` e localização dos metadados versionáveis | DSG-0002, MOD-0002, CTR-0001, PST-0001 |
| ADR-0009 | Normalização e contratos de dados | `refinement` | `refined` | Separar contrato lógico de transporte/encoding | MOD-0001, CTR-0001, PRM-0001 |
| ADR-0010 | Assembler e invocação | `refinement` | `refined` | Definir binding posicional, flag, boolean, ambiente e stdin | MOD-0003, MOD-0004, MOD-0005, CTR-0001 |
| ADR-0011 | Functions geradas | `refinement` | `refined` | Definir análise estrutural, namespace, top-level proibido e colisões | MOD-0004, FLW-0001 |
| ADR-0012 | Segurança/policy | `refinement` | `refined` | Estruturar efeitos da capability e regra de autorização | DSG-0002, MOD-0004, CTR-0001 |
| ADR-0013 | Tool loop e contexto | `refinement` | `refined` | Definir sessão, limite de contexto, resultados de tools e número de turnos | MOD-0003, FLW-0001 |
| ADR-0014 | Runtime de inferência | `refinement` | `refined` | Escolher modelo único na V1 ou lifecycle explícito de múltiplos modelos | DSG-0003, CTR-0003 |
| ADR-0015 | API externa | `refinement` | `refined` | Definir envelopes, correlação, erros, cancelamento, framing e limites | DSG-0003, CTR-0004, FLW-0005 |

## BLOCKED — desenho

- **DSG-0002 — Catálogo de capabilities**
  - estado atual: `backlog`;
  - estado necessário para liberar especificações dependentes: `finalized`;
  - bloqueadores: ADR-0008 e ADR-0012.

- **DSG-0003 — Runtime do daemon**
  - estado atual: `backlog`;
  - estado necessário para liberar especificações dependentes: `finalized`;
  - bloqueadores: ADR-0013, ADR-0014 e ADR-0015.

## Pendências HIGH

As seguintes lacunas continuam sem definição normativa suficiente:

1. tipagem de literais com `TypedValue`;
2. política para captura escalar de `result_ref`;
3. semântica de códigos de saída por implementation;
4. manifesto de dependências do `BashArtifact`;
5. portabilidade `SELF_CONTAINED` versus `HOST_BOUND`;
6. validação em runtime de checksums de dependências externas;
7. ator, auditoria e operações administrativas de approve/activate/block/deprecate;
8. testes funcionais de capabilities e critério de promoção;
9. tratamento de prompt injection em resultados de MCP/tool;
10. backpressure, fila, deadlines e propagação de cancelamento;
11. snapshot de configuração durante uma requisição;
12. estratégia de migrations e compatibilidade de schema PostgreSQL.

## Pendências MEDIUM

1. benchmark TextProto x JSON compacto com tokenizer real;
2. ranking e desempate determinísticos da busca;
3. canonicalização formal da fingerprint;
4. `risk_level` como enum/constraint;
5. validação explícita de `requested_filename` e separação do diretório de saída;
6. versionamento funcional de protocolo, pipeline e contrato de capability.

## Inconsistências corrigidas na reorganização

- A documentação anterior chamava `DataContract` de lógico enquanto incluía `StreamEncoding`; agora a divergência está explicitamente bloqueada por ADR-0009.
- A busca retornava identidade lógica e o detalhe podia resolver novamente a versão ativa; a condição de corrida está explicitamente bloqueada por ADR-0008.
- Metadados pesquisáveis apareciam na identidade `capability` apesar de poderem variar por versão; a decisão foi reaberta em ADR-0008.
- Os diagramas antigos representavam decisões V1 enquanto a V2 já apontava bloqueios novos; os desenhos ADP agora declaram dependências e estado.
- `AGENTS.md` e `MCP.md` misturavam decisões, contratos, persistência, configuração e fluxo; o conteúdo foi separado por responsabilidade.

## Critério para desenvolvimento

Nenhum item dependente dos ADRs e desenhos acima deve ser tratado como liberado apenas pela existência de especificação textual. O gate aplicável continua sendo o do ADP 1.0.
