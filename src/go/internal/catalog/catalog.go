package catalog

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/config"
	"github.com/ahhvahh/ai-bash-generator/internal/observability"
)

type TaskQuery struct {
	ID                string
	Instruction       string
	InputDescription  string
	OutputDescription string
}

type SearchRequest struct {
	Intent               string
	CanonicalInstruction string
	InputDescription     string
	OutputDescription    string
	Tasks                []TaskQuery
}

type Candidate struct {
	ID                string `json:"id"`
	Type              string `json:"type"`
	Description       string `json:"description"`
	MatchInstruction  string `json:"match_instruction"`
	InputDescription  string `json:"input_description"`
	OutputDescription string `json:"output_description"`
}

type TaskCandidates struct {
	TaskID     string
	Candidates []Candidate
}

type SearchResult struct {
	Composite []Candidate
	Tasks     []TaskCandidates
}

type Searcher interface {
	Search(context.Context, SearchRequest) (SearchResult, error)
}

type Client struct {
	cfg config.DatabaseConfig
}

func New(cfg config.DatabaseConfig) *Client {
	return &Client{cfg: cfg}
}

func (c *Client) Ping(ctx context.Context) error {
	if !c.cfg.Required {
		return nil
	}
	probe, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	args := c.psqlArgs()
	args = append(args, "--command", "SELECT 1;")
	cmd := exec.CommandContext(probe, "psql", args...)
	if data, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("PostgreSQL indisponível: %w: %s", err, strings.TrimSpace(string(data)))
	}
	return nil
}

func (c *Client) Search(ctx context.Context, req SearchRequest) (SearchResult, error) {
	if !c.cfg.Required {
		return SearchResult{}, nil
	}
	logger := observability.Logger(ctx).With("component", "capability-catalog")
	started := time.Now()

	compositeQuery := strings.TrimSpace(strings.Join([]string{
		req.Intent,
		req.CanonicalInstruction,
		req.InputDescription,
		req.OutputDescription,
	}, " "))

	composite, err := c.searchOne(ctx, req.Intent, compositeQuery)
	if err != nil {
		return SearchResult{}, fmt.Errorf("buscar capability composta: %w", err)
	}

	result := SearchResult{Composite: composite}
	for _, task := range req.Tasks {
		query := strings.TrimSpace(strings.Join([]string{
			task.Instruction,
			task.InputDescription,
			task.OutputDescription,
		}, " "))
		candidates, err := c.searchOne(ctx, "", query)
		if err != nil {
			return SearchResult{}, fmt.Errorf("buscar capabilities da task %s: %w", task.ID, err)
		}
		result.Tasks = append(result.Tasks, TaskCandidates{
			TaskID:     task.ID,
			Candidates: candidates,
		})
		logger.Debug("consulta de capability concluída",
			"event", "capability_search_task",
			"task_id", task.ID,
			"candidate_count", len(candidates),
		)
	}

	logger.Info("pesquisa de capabilities concluída",
		"event", "capability_search_complete",
		"database_query_executed", true,
		"database", "postgresql",
		"composite_candidates", len(result.Composite),
		"task_queries", len(result.Tasks),
		"task_candidates", result.TaskCandidateCount(),
		"duration_ms", time.Since(started).Milliseconds(),
	)
	return result, nil
}

func (c *Client) searchOne(ctx context.Context, intent, query string) ([]Candidate, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, nil
	}

	sql := `
SELECT json_build_object(
  'id', c.id,
  'type', c.type,
  'description', c.description,
  'match_instruction', c.match_instruction,
  'input_description', c.input_description,
  'output_description', c.output_description
)::text
FROM capability_catalog.capability c
WHERE c.enabled
  AND EXISTS (
    SELECT 1
    FROM capability_catalog.capability_version v
    WHERE v.capability_id = c.id
      AND v.active
  )
  AND (
    (:'intent' <> '' AND lower(c.intent) = lower(:'intent'))
    OR c.search_document @@ websearch_to_tsquery('english', :'query')
  )
ORDER BY
  CASE WHEN :'intent' <> '' AND lower(c.intent) = lower(:'intent') THEN 1 ELSE 0 END DESC,
  ts_rank_cd(c.search_document, websearch_to_tsquery('english', :'query')) DESC,
  c.id
LIMIT ` + strconv.Itoa(c.cfg.SearchLimit) + ";"

	args := c.psqlArgs()
	args = append(args,
		"--set", "ON_ERROR_STOP=1",
		"--set", "intent="+intent,
		"--set", "query="+query,
		"--command", sql,
	)

	cmd := exec.CommandContext(ctx, "psql", args...)
	data, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("psql falhou: %w: %s", err, strings.TrimSpace(string(data)))
	}

	var candidates []Candidate
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var candidate Candidate
		if err := json.Unmarshal([]byte(line), &candidate); err != nil {
			return nil, fmt.Errorf("decodificar candidato PostgreSQL: %w", err)
		}
		candidates = append(candidates, candidate)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return candidates, nil
}

func (c *Client) psqlArgs() []string {
	return []string{
		"--no-psqlrc",
		"--no-align",
		"--tuples-only",
		"--host", c.cfg.Host,
		"--port", strconv.Itoa(c.cfg.Port),
		"--dbname", c.cfg.Name,
		"--username", c.cfg.User,
	}
}

func (r SearchResult) TaskCandidateCount() int {
	total := 0
	for _, task := range r.Tasks {
		total += len(task.Candidates)
	}
	return total
}

func (r SearchResult) FormatTextProto() string {
	var b strings.Builder
	for _, candidate := range r.Composite {
		b.WriteString("composite_candidates {\n")
		writeCandidate(&b, candidate, "  ")
		b.WriteString("}\n")
	}
	for _, task := range r.Tasks {
		b.WriteString("task_candidates {\n")
		fmt.Fprintf(&b, "  task_id: %q\n", task.TaskID)
		for _, candidate := range task.Candidates {
			b.WriteString("  candidates {\n")
			writeCandidate(&b, candidate, "    ")
			b.WriteString("  }\n")
		}
		b.WriteString("}\n")
	}
	if b.Len() == 0 {
		return "# no capability candidates found\n"
	}
	return b.String()
}

func writeCandidate(b *strings.Builder, c Candidate, indent string) {
	fmt.Fprintf(b, "%sid: %q\n", indent, c.ID)
	fmt.Fprintf(b, "%stype: %q\n", indent, c.Type)
	fmt.Fprintf(b, "%sdescription: %q\n", indent, c.Description)
	fmt.Fprintf(b, "%smatch_instruction: %q\n", indent, c.MatchInstruction)
	fmt.Fprintf(b, "%sinput_description: %q\n", indent, c.InputDescription)
	fmt.Fprintf(b, "%soutput_description: %q\n", indent, c.OutputDescription)
}
