package catalog

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"

	"github.com/ahhvahh/ai-bash-generator/internal/config"
)

type Searcher struct {
	cfg config.DatabaseConfig
}

func New(cfg config.DatabaseConfig) *Searcher {
	return &Searcher{cfg: cfg}
}

func (s *Searcher) Search(ctx context.Context, normalizedTextProto string) (string, error) {
	if !s.cfg.Enabled {
		return "database_enabled: false\n", nil
	}

	queries := extractSearchQueries(normalizedTextProto)
	if len(queries) == 0 {
		return "", fmt.Errorf("NormalizedRequest não contém canonical_instruction nem tarefas pesquisáveis")
	}

	var out strings.Builder
	fmt.Fprintf(&out, "database: %s\n", s.cfg.Name)
	fmt.Fprintf(&out, "queries: %d\n", len(queries))

	for i, q := range queries {
		rows, err := s.searchOne(ctx, q)
		if err != nil {
			return "", fmt.Errorf("buscar capability para %q: %w", q, err)
		}
		fmt.Fprintf(&out, "\nquery[%d]: %s\n", i, q)
		if len(rows) == 0 {
			out.WriteString("  candidates: 0\n")
			continue
		}
		fmt.Fprintf(&out, "  candidates: %d\n", len(rows))
		for _, row := range rows {
			fmt.Fprintf(&out, "  - id: %s\n", row[0])
			fmt.Fprintf(&out, "    type: %s\n", row[1])
			fmt.Fprintf(&out, "    description: %s\n", row[2])
			fmt.Fprintf(&out, "    match_instruction: %s\n", row[3])
			fmt.Fprintf(&out, "    input_description: %s\n", row[4])
			fmt.Fprintf(&out, "    output_description: %s\n", row[5])
		}
	}
	return out.String(), nil
}

func (s *Searcher) searchOne(ctx context.Context, query string) ([][]string, error) {
	limit := s.cfg.SearchLimit
	if limit <= 0 {
		limit = 8
	}

	sql := `
SELECT
  id,
  capability_type,
  replace(description, E'\\n', ' '),
  replace(match_instruction, E'\\n', ' '),
  replace(input_description, E'\\n', ' '),
  replace(output_description, E'\\n', ' ')
FROM capability_catalog.capability
WHERE enabled
  AND search_vector @@ websearch_to_tsquery('simple', :'query')
ORDER BY ts_rank(search_vector, websearch_to_tsquery('simple', :'query')) DESC, id
LIMIT :limit;
`

	args := []string{
		"-X", "-A", "-t", "-F", "\x1f",
		"-v", "ON_ERROR_STOP=1",
		"-v", "query=" + query,
		"-v", "limit=" + strconv.Itoa(limit),
		"-h", s.cfg.Host,
		"-p", strconv.Itoa(s.cfg.Port),
		"-U", s.cfg.User,
		"-d", s.cfg.Name,
		"-c", sql,
	}
	cmd := exec.CommandContext(ctx, "psql", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	data, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("psql: %w: %s", err, strings.TrimSpace(stderr.String()))
	}

	var rows [][]string
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "" {
			continue
		}
		parts := strings.Split(line, "\x1f")
		for len(parts) < 6 {
			parts = append(parts, "")
		}
		rows = append(rows, parts[:6])
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return rows, nil
}

func extractSearchQueries(text string) []string {
	var queries []string
	seen := map[string]bool{}
	for _, raw := range strings.Split(text, "\n") {
		line := strings.TrimSpace(raw)
		var value string
		switch {
		case strings.HasPrefix(line, "canonical_instruction:"):
			value = parseTextProtoString(strings.TrimSpace(strings.TrimPrefix(line, "canonical_instruction:")))
		case strings.HasPrefix(line, "instruction:"):
			value = parseTextProtoString(strings.TrimSpace(strings.TrimPrefix(line, "instruction:")))
		default:
			continue
		}
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		queries = append(queries, value)
	}
	return queries
}

func parseTextProtoString(value string) string {
	value = strings.TrimSpace(value)
	if len(value) >= 2 && value[0] == '"' && value[len(value)-1] == '"' {
		if unquoted, err := strconv.Unquote(value); err == nil {
			return unquoted
		}
	}
	return strings.Trim(value, "'")
}
