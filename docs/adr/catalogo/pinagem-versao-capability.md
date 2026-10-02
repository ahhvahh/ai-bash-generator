# Identidade e pinagem de versão da capability

![ADR](https://img.shields.io/badge/ADR-ADR--0008-7a3e9d?style=flat-square)
![Status](https://img.shields.io/badge/Status-refinement-d4a72c?style=flat-square)
![Version](https://img.shields.io/badge/Version----6e7781?style=flat-square)

## Contexto

A busca avalia uma versão ativa e o gerador pode solicitar o detalhe posteriormente.

## Problema

Resolver novamente a versão ativa em `get_capability(id)` permite TOCTOU. Metadados pesquisáveis que variam por versão também podem divergir do conteúdo imutável.

## Restrições

- O candidato avaliado pelo pruning deve ser o mesmo carregado depois.
- Identidade lógica deve permanecer estável.
- Conteúdo versionável não pode ter duas fontes de verdade.

## Opções consideradas

### Resolver versão ativa novamente no detalhe

Mantém API simples, mas não garante consistência.

### Fixar `capability_version_id` no candidato

A busca devolve a versão imutável usada pelo pruning e o detalhe carrega exatamente essa versão.

### Metadados na identidade ou na versão

Ainda precisa ser definido quais campos são realmente estáveis.

## Decisão

Em refinamento. Nenhuma opção foi aprovada.

## Justificativa

A revisão propõe fixar `capability_version_id` e mover metadados variáveis para a versão, mas isso precisa ser formalizado antes de liberar o desenho do catálogo.

## Consequências

DSG-0002, MOD-0002, CTR-0001 e PST-0001 permanecem bloqueados.

## Dependências

- [ADR-0004](../persistencia/catalogo-capabilities.md)

## Critérios de validação

- Definir campos estáveis da identidade.
- Definir campos versionados.
- Definir chave canônica de `get_capability`.
- Eliminar mudança de versão entre search e detail.
