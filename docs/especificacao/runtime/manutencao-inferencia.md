# Manutenção da inferência

**ID:** OPS-0001  
**Status:** specification

## Objetivo

Permitir manutenção local dos dois agentes de inferência — `normalizer` e `generator` — sem recompilar ou publicar um novo pacote Debian a cada ajuste de prompt, modelo ou sampling.

Essa capacidade precisa ser implementada uma vez no binário. Depois disso, alterações operacionais devem ser persistidas fora do executável.

## Estado atual verificado no repositório

Na referência `main@a734af859d800487b51b5136d5772397dc12ffc6`:

- `normalizerSystemPrompt` e `generatorSystemPrompt` estão compilados em `src/go/internal/pipeline/runner.go`;
- normalizer e generator já podem usar modelos e parâmetros separados na configuração;
- a configuração expõe `model`, `max_tokens` e `temperature` para cada agente;
- não existe CLI de manutenção de prompts;
- não existe hot reload de prompt ou modelo;
- o daemon gerencia dois processos `llama-server`, um por agente.

Portanto, **hoje não é possível trocar o prompt efetivo sem atualizar o binário**. A externalização abaixo é requisito para eliminar essa limitação.

## Persistência requerida

Prompts efetivos:

```text
/etc/ai-bash-gen/prompts/request-normalizer.txt
/etc/ai-bash-gen/prompts/bash-generator.txt
```

Configuração dos agentes:

```text
/etc/ai-bash-gen/config.yaml
```

Modelos:

```text
/var/lib/ai-bash-gen/models/
```

O binário deve possuir prompts padrão embutidos apenas como fallback. Se existir um arquivo externo válido, ele prevalece.

Cada prompt efetivo deve possuir SHA-256 calculado e exibível para diagnóstico.

## CLI requerida

A mesma interface deve funcionar para `normalizer` e `generator`.

### Prompt

```bash
ai-bash-gen inference prompt show --agent normalizer
ai-bash-gen inference prompt set --agent normalizer --file ./request-normalizer.txt
ai-bash-gen inference prompt reset --agent normalizer

ai-bash-gen inference prompt show --agent generator
ai-bash-gen inference prompt set --agent generator --file ./bash-generator.txt
ai-bash-gen inference prompt reset --agent generator
```

`show` deve informar origem do prompt (`embedded` ou `override`), caminho quando houver arquivo externo e SHA-256.

`set` deve validar arquivo não vazio, persistir de forma atômica e solicitar recarga somente do agente afetado.

`reset` remove o override e volta ao prompt padrão compilado.

### Modelo

```bash
ai-bash-gen inference model show --agent normalizer
ai-bash-gen inference model list
ai-bash-gen inference model set --agent normalizer --path /var/lib/ai-bash-gen/models/test-normalizer.gguf

ai-bash-gen inference model show --agent generator
ai-bash-gen inference model set --agent generator --path /var/lib/ai-bash-gen/models/test-generator.gguf
```

`model set` deve validar existência, acesso de leitura e assinatura GGUF antes de alterar a configuração. A troca deve reiniciar apenas o processo `llama-server` do agente afetado quando a implementação permitir; reiniciar todo o daemon é fallback aceitável.

### Parâmetros

```bash
ai-bash-gen inference params list --agent normalizer
ai-bash-gen inference params set --agent normalizer temperature=0.1 max_tokens=2048

ai-bash-gen inference params list --agent generator
ai-bash-gen inference params set --agent generator temperature=0.2 max_tokens=4096
```

`params list` não deve depender apenas de uma lista codificada no Go. Ele deve consultar o `llama-server` efetivo do agente, preferencialmente via `GET /props`, e apresentar os parâmetros suportados pelo runtime instalado junto com os valores efetivos.

Parâmetros de sampling que podem existir no `llama-server` incluem `temperature`, `top_k`, `top_p`, `min_p`, `seed`, penalidades de repetição, presença/frequência e outros. O comando deve mostrar somente o que o runtime efetivamente informar como suportado.

Parâmetros que exigem reinicialização do processo devem ser identificados como `restart_required`; parâmetros aplicáveis por requisição podem ser alterados sem trocar o modelo.

### Recarga

```bash
ai-bash-gen inference reload --agent normalizer
ai-bash-gen inference reload --agent generator
ai-bash-gen inference reload --all
```

A recarga deve ser transacional: se o novo prompt, modelo ou configuração não puder ser carregado, o agente anterior continua disponível.

## Verificação do serviço e acesso local

Os seguintes comandos existem ou dependem apenas do Linux e podem ser usados no ambiente instalado:

```bash
ai-bash-gen --show-paths
systemctl status ai-bash-gen --no-pager
id
ls -ld /run/ai-bash-gen /run/ai-bash-gen/routes
ls -l /run/ai-bash-gen/routes/generate.sock
namei -l /run/ai-bash-gen/routes/generate.sock
```

Para validar o socket sem executar o Bash retornado:

```bash
ai-bash-gen-generation-test --socket /run/ai-bash-gen/routes/generate.sock
```

Se o utilitário não estiver no `PATH`, localizar o binário instalado antes de concluir que o usuário não possui acesso.

## Alteração manual disponível antes da nova CLI

Se o `config.yaml` instalado já possuir seções `normalizer` e `generator`, modelo, `temperature` e `max_tokens` podem ser alterados sem novo pacote por edição da configuração seguida de reinício:

```bash
sudoedit /etc/ai-bash-gen/config.yaml
sudo systemctl restart ai-bash-gen
sudo journalctl -u ai-bash-gen -n 100 --no-pager
```

Essa alternativa **não resolve alteração de prompt**, pois os prompts atuais estão compilados no binário.

## Segurança

Operações de geração e operações administrativas não devem compartilhar automaticamente a mesma autorização.

A interface administrativa deve permanecer local, via Unix Domain Socket ou execução local, e exigir grupo administrativo próprio. Ter acesso a `generate.sock` não deve, por si só, autorizar troca de prompt, modelo ou parâmetros.

Nenhuma interface de manutenção deve abrir porta TCP.

## Critérios de aceite

- Prompt de cada agente pode ser alterado sem novo pacote.
- Prompt efetivo, origem e SHA-256 podem ser consultados.
- Modelo de cada agente pode ser trocado e validado independentemente.
- Parâmetros suportados podem ser descobertos a partir do runtime efetivo.
- Parâmetros persistentes podem ser alterados separadamente por agente.
- Falha de recarga preserva a configuração funcional anterior.
- Toda manutenção permanece local e auditável.
