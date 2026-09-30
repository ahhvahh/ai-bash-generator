# NormalizedRequest

Este documento define exclusivamente como o `ai-bash-gen` transforma uma solicitação em linguagem natural em uma representação técnica curta, estável e em inglês.

## Objetivo

O primeiro LLM do pipeline deve ser pequeno e barato.

Ele não gera Bash, não consulta MCPs e não decide qual capability utilizar.

Sua única responsabilidade é converter a frase do usuário em uma `NormalizedRequest`.

Exemplo:

```text
Usuário:
liste os itens da pasta ~/ambiente mostrando nome,
tamanho e permissão, do maior para o menor
```

Saída:

```json
{
  "intent": "list_directory_items",
  "canonical_instruction": "List directory items with selected metadata and sorting.",

  "input_description": "Directory path, selected fields, sort field and sort direction.",
  "output_description": "Table containing name, size and permissions ordered by size descending.",

  "input": [
    {
      "name": "path",
      "type": "path",
      "value": "~/ambiente"
    },
    {
      "name": "fields",
      "type": "list<string>",
      "value": ["name", "size", "permissions"]
    },
    {
      "name": "sort_by",
      "type": "string",
      "value": "size"
    },
    {
      "name": "sort_order",
      "type": "string",
      "value": "desc"
    }
  ],

  "processing": [
    "Enumerate directory items.",
    "Collect requested metadata.",
    "Sort rows by size descending."
  ],

  "output": [
    {
      "type": "table",
      "fields": ["name", "size", "permissions"]
    }
  ]
}
```

## Regras

### 1. Inglês como linguagem canônica

Os campos usados para descoberta devem ser escritos em inglês:

- `intent`;
- `canonical_instruction`;
- `input_description`;
- `output_description`;
- `processing`.

Valores fornecidos pelo usuário não devem ser traduzidos ou alterados.

Exemplo:

```text
~/ambiente
/data
500 MB
relatorio.txt
```

devem permanecer como foram informados.

### 2. Separar intenção de valores concretos

Evitar:

```text
List subdirectories in ~/ambiente.
```

Preferir:

```text
canonical_instruction:
List subdirectories in a directory.

input:
base_path = ~/ambiente
```

Isso permite que a mesma instrução seja comparada com capabilities genéricas.

### 3. `intent`

Deve ser curto, técnico e estável.

Formato recomendado:

```text
snake_case
```

Exemplos:

```text
list_subdirectories
list_directory_items
find_large_files
create_directory_archive
read_email_messages
```

O `intent` não deve conter valores da requisição.

Evitar:

```text
list_subdirectories_in_home_ambiente
```

### 4. `canonical_instruction`

É uma frase curta que descreve o comportamento principal.

Exemplos:

```text
List subdirectories in a directory.
List directory items with selected metadata and sorting.
Find files larger than a size threshold.
Create a compressed archive from a directory.
```

Ela deve ser genérica o suficiente para localizar uma capability reutilizável.

### 5. `input_description`

Resumo em uma frase dos tipos de entrada e opções esperadas.

Exemplo:

```text
Directory path, selected fields, sort field and sort direction.
```

Esse campo será comparado com o `input_description` das capabilities.

### 6. `output_description`

Resumo em uma frase da forma da saída solicitada.

Exemplo:

```text
Table containing name, size and permissions ordered by size descending.
```

Esse campo ajuda a distinguir capabilities que executam operações parecidas, mas retornam resultados diferentes.

### 7. `input`

Contém parâmetros concretos extraídos da solicitação.

Cada entrada pode possuir:

```json
{
  "name": "path",
  "type": "path",
  "value": "~/ambiente"
}
```

O normalizador não deve inventar valores ausentes.

Quando um valor necessário não estiver disponível, utilizar:

```json
{
  "name": "destination",
  "type": "path",
  "required": true,
  "value": null
}
```

### 8. `processing`

Descreve as transformações necessárias sem escolher comandos Bash.

Correto:

```text
Enumerate directory items.
Collect requested metadata.
Sort rows by size descending.
```

Evitar:

```text
Run find.
Pipe to sort -nr.
Use awk.
```

A escolha dos comandos pertence ao gerador ou à capability encontrada.

### 9. `output`

Define a estrutura lógica desejada.

Exemplo:

```json
[
  {
    "type": "table",
    "fields": ["name", "size", "permissions"]
  }
]
```

Outros exemplos:

```json
[
  {
    "type": "list<path>"
  }
]
```

```json
[
  {
    "type": "file",
    "format": "gzip"
  }
]
```

## Contrato inicial

```json
{
  "intent": "string",
  "canonical_instruction": "string",
  "input_description": "string",
  "output_description": "string",
  "input": [],
  "processing": [],
  "output": []
}
```

## Exemplos

### Listar somente nomes

Usuário:

```text
liste os arquivos de /dados por nome
```

```json
{
  "intent": "list_directory_items",
  "canonical_instruction": "List directory items with selected metadata and sorting.",
  "input_description": "Directory path, selected fields and sort field.",
  "output_description": "List containing item names ordered by name.",
  "input": [
    {"name":"path","type":"path","value":"/dados"},
    {"name":"fields","type":"list<string>","value":["name"]},
    {"name":"sort_by","type":"string","value":"name"},
    {"name":"sort_order","type":"string","value":"asc"}
  ],
  "processing": [
    "Enumerate directory items.",
    "Return requested fields.",
    "Sort by name ascending."
  ],
  "output": [
    {"type":"list","fields":["name"]}
  ]
}
```

### Listar nome e tamanho

Usuário:

```text
mostre nome e tamanho dos arquivos em /dados, maiores primeiro
```

```json
{
  "intent": "list_directory_items",
  "canonical_instruction": "List directory items with selected metadata and sorting.",
  "input_description": "Directory path, selected fields, sort field and sort direction.",
  "output_description": "Table containing name and size ordered by size descending.",
  "input": [
    {"name":"path","type":"path","value":"/dados"},
    {"name":"fields","type":"list<string>","value":["name","size"]},
    {"name":"sort_by","type":"string","value":"size"},
    {"name":"sort_order","type":"string","value":"desc"}
  ],
  "processing": [
    "Enumerate directory items.",
    "Collect name and size.",
    "Sort by size descending."
  ],
  "output": [
    {"type":"table","fields":["name","size"]}
  ]
}
```

### Encontrar arquivos grandes

Usuário:

```text
procure arquivos maiores que 500 MB em /var/log
```

```json
{
  "intent": "find_large_files",
  "canonical_instruction": "Find files larger than a size threshold.",
  "input_description": "Base directory and minimum file size.",
  "output_description": "List of file paths matching the size threshold.",
  "input": [
    {"name":"path","type":"path","value":"/var/log"},
    {"name":"minimum_size","type":"size","value":"500 MB"}
  ],
  "processing": [
    "Traverse files below the base directory.",
    "Keep files larger than the threshold."
  ],
  "output": [
    {"type":"list<path>"}
  ]
}
```

## Validação

A aplicação deve validar a saída antes de continuar.

Rejeitar:

- JSON inválido;
- `intent` vazio;
- instrução vazia;
- descrições vazias;
- valores inventados;
- comandos Bash em `processing`;
- campos fora do schema quando o modo estrito estiver habilitado.

## Uso no próximo estágio

A `NormalizedRequest` alimenta diretamente a pesquisa do catálogo:

```text
intent
canonical_instruction
input_description
output_description
        |
        v
search_capabilities
```

Os valores concretos de `input` são usados posteriormente para montar a invocação específica da capability selecionada.
