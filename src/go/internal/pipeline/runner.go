package pipeline

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/observability"
	"github.com/ahhvahh/ai-bash-generator/internal/output"
	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

const maxGenerationAttempts = 2

type Completer interface {
	Complete(ctx context.Context, systemPrompt, userPrompt string) (string, error)
}

type CapabilitySearcher interface {
	Search(ctx context.Context, normalizedTextProto string) (string, error)
}

type Runner struct {
	normalizer Completer
	generator  Completer
	searcher   CapabilitySearcher
	timeout    time.Duration
}

func NewRunner(normalizer, generator Completer, searcher CapabilitySearcher, timeout time.Duration) *Runner {
	return &Runner{normalizer: normalizer, generator: generator, searcher: searcher, timeout: timeout}
}

func (r *Runner) Generate(ctx context.Context, request protocol.GenerateRequest, progress func(protocol.Stage, protocol.ProgressState, string) error) (protocol.GenerateResult, error) {
	if r.normalizer == nil {
		return protocol.GenerateResult{}, errors.New("request-normalizer não configurado")
	}
	if r.generator == nil {
		return protocol.GenerateResult{}, errors.New("bash-generator não configurado")
	}
	if r.searcher == nil {
		return protocol.GenerateResult{}, errors.New("Capability Catalog não configurado")
	}
	if strings.TrimSpace(request.Text) == "" {
		return protocol.GenerateResult{}, errors.New("instrução vazia")
	}
	if request.StopAfterStage > protocol.StageBashOutput {
		return protocol.GenerateResult{}, fmt.Errorf("stop_after_stage inválido: %d", request.StopAfterStage)
	}

	ctx, cancel := context.WithTimeout(ctx, r.timeout)
	defer cancel()
	logger := observability.Logger(ctx).With("component", "pipeline")
	pipelineStarted := time.Now()

	logger.Debug("pipeline iniciado",
		"event", "pipeline_start",
		"timeout_ms", r.timeout.Milliseconds(),
		"requested_filename", request.RequestedFilename,
		"stop_after_stage", request.StopAfterStage.String(),
	)

	// 1. request-normalizer
	if err := progress(protocol.StageRequestNormalizer, protocol.StateStarted, "normalizando solicitação com request-normalizer"); err != nil {
		return protocol.GenerateResult{}, err
	}
	normalizeStarted := time.Now()
	normalized, err := r.normalizer.Complete(ctx, normalizerSystemPrompt, request.Text)
	if err != nil {
		_ = progress(protocol.StageRequestNormalizer, protocol.StateFailed, err.Error())
		return protocol.GenerateResult{}, fmt.Errorf("request-normalizer: %w", err)
	}
	normalized = strings.TrimSpace(normalized)
	if err := validateNormalizedRequest(normalized); err != nil {
		_ = progress(protocol.StageRequestNormalizer, protocol.StateFailed, err.Error())
		return protocol.GenerateResult{}, fmt.Errorf("NormalizedRequest inválida: %w", err)
	}
	logger.Info("solicitação normalizada por LLM",
		"event", "request_normalized",
		"duration_ms", time.Since(normalizeStarted).Milliseconds(),
		"input_chars", len([]rune(request.Text)),
		"normalized_chars", len([]rune(normalized)),
		"normalization_status", normalizationStatus(normalized),
		"task_count", strings.Count(normalized, "tasks {"),
	)
	if err := progress(protocol.StageRequestNormalizer, protocol.StateCompleted, fmt.Sprintf("NormalizedRequest pronta; tarefas=%d", strings.Count(normalized, "tasks {"))); err != nil {
		return protocol.GenerateResult{}, err
	}
	if request.StopAfterStage == protocol.StageRequestNormalizer {
		return stageResult(protocol.StageRequestNormalizer, "application/x-protobuf-text", normalized), nil
	}
	if strings.Contains(normalized, "NORMALIZATION_STATUS_MISSING_INFORMATION") {
		return protocol.GenerateResult{}, errors.New("request-normalizer indicou informação obrigatória ausente")
	}

	// 2. search-capabilities
	if err := progress(protocol.StageSearchCapabilities, protocol.StateStarted, "consultando PostgreSQL/Capability Catalog para requisição e tarefas"); err != nil {
		return protocol.GenerateResult{}, err
	}
	searchStarted := time.Now()
	candidates, err := r.searcher.Search(ctx, normalized)
	if err != nil {
		_ = progress(protocol.StageSearchCapabilities, protocol.StateFailed, err.Error())
		return protocol.GenerateResult{}, fmt.Errorf("search-capabilities: %w", err)
	}
	logger.Info("consulta ao catálogo de capabilities concluída",
		"event", "database_search_complete",
		"stage", "search-capabilities",
		"database", "postgresql",
		"database_query_executed", true,
		"duration_ms", time.Since(searchStarted).Milliseconds(),
		"result_chars", len([]rune(candidates)),
	)
	if err := progress(protocol.StageSearchCapabilities, protocol.StateCompleted, "PostgreSQL consultado para a instrução canônica e para cada tarefa"); err != nil {
		return protocol.GenerateResult{}, err
	}
	if request.StopAfterStage == protocol.StageSearchCapabilities {
		return stageResult(protocol.StageSearchCapabilities, "text/plain; charset=utf-8", candidates), nil
	}

	// 3. bash-generator
	var content string
	var validationErr error
	for attempt := 1; attempt <= maxGenerationAttempts; attempt++ {
		message := fmt.Sprintf("gerando Bash a partir da NormalizedRequest e capabilities (tentativa %d/%d)", attempt, maxGenerationAttempts)
		userPrompt := buildGeneratorInput(normalized, candidates)
		if attempt > 1 {
			message = fmt.Sprintf("regenerando após falha de validação (tentativa %d/%d)", attempt, maxGenerationAttempts)
			userPrompt = buildRepairPrompt(normalized, candidates, validationErr)
		}
		if err := progress(protocol.StageBashGenerator, protocol.StateStarted, message); err != nil {
			return protocol.GenerateResult{}, err
		}

		logger.Info("tentativa de geração iniciada",
			"event", "generation_attempt_start",
			"attempt", attempt,
			"max_attempts", maxGenerationAttempts,
			"repair", attempt > 1,
		)
		generated, err := r.generator.Complete(ctx, generatorSystemPrompt, userPrompt)
		if err != nil {
			_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
			return protocol.GenerateResult{}, fmt.Errorf("bash-generator tentativa %d/%d: %w", attempt, maxGenerationAttempts, err)
		}
		content = cleanGeneratedBash(generated)
		if strings.TrimSpace(content) == "" {
			err := errors.New("modelo retornou script vazio")
			_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
			return protocol.GenerateResult{}, err
		}
		if err := progress(protocol.StageBashGenerator, protocol.StateCompleted, fmt.Sprintf("Bash gerado (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
			return protocol.GenerateResult{}, err
		}
		if request.StopAfterStage == protocol.StageBashGenerator {
			return stageResult(protocol.StageBashGenerator, "text/x-shellscript; charset=utf-8", content), nil
		}

		// 4. validation
		if err := progress(protocol.StageValidation, protocol.StateStarted, fmt.Sprintf("validando sintaxe com bash -n (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
			return protocol.GenerateResult{}, err
		}
		validationStarted := time.Now()
		validationErr = validateBash(ctx, content)
		if validationErr == nil {
			logger.Info("validação sintática concluída",
				"event", "bash_validation_complete",
				"attempt", attempt,
				"validator", "bash -n",
				"duration_ms", time.Since(validationStarted).Milliseconds(),
			)
			if err := progress(protocol.StageValidation, protocol.StateCompleted, fmt.Sprintf("bash -n aprovado (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
				return protocol.GenerateResult{}, err
			}
			break
		}

		logger.Warn("script gerado falhou na validação sintática",
			"event", "generation_validation_failed",
			"attempt", attempt,
			"max_attempts", maxGenerationAttempts,
			"validation_error", validationErr.Error(),
		)
		if attempt < maxGenerationAttempts {
			_ = progress(protocol.StageValidation, protocol.StateFailed, validationErr.Error())
			continue
		}
		_ = progress(protocol.StageValidation, protocol.StateFailed, validationErr.Error())
		return protocol.GenerateResult{}, fmt.Errorf("script Bash inválido após %d tentativas: %w", maxGenerationAttempts, validationErr)
	}

	if request.StopAfterStage == protocol.StageValidation {
		body := "validator: bash -n\nstatus: OK\n\n" + content
		return stageResult(protocol.StageValidation, "text/plain; charset=utf-8", body), nil
	}

	// 5. bash-output
	if err := progress(protocol.StageBashOutput, protocol.StateStarted, "materializando artefato Bash"); err != nil {
		return protocol.GenerateResult{}, err
	}
	filename := request.RequestedFilename
	if filename == "" {
		filename = "generated.sh"
	}
	if err := output.ValidateFilename(filename); err != nil {
		_ = progress(protocol.StageBashOutput, protocol.StateFailed, err.Error())
		return protocol.GenerateResult{}, fmt.Errorf("filename final inválido: %w", err)
	}
	sum := sha256.Sum256([]byte(content))
	artifact := protocol.BashArtifact{
		Filename:       filename,
		Content:        content,
		SHA256:         hex.EncodeToString(sum[:]),
		FinalOutputRef: filename,
	}
	if err := progress(protocol.StageBashOutput, protocol.StateCompleted, "artefato Bash pronto"); err != nil {
		return protocol.GenerateResult{}, err
	}

	logger.Info("pipeline concluído",
		"event", "pipeline_complete",
		"duration_ms", time.Since(pipelineStarted).Milliseconds(),
		"filename", artifact.Filename,
		"sha256", artifact.SHA256,
	)

	if request.StopAfterStage == protocol.StageBashOutput {
		body := fmt.Sprintf("filename: %s\nsha256: %s\n\n%s", artifact.Filename, artifact.SHA256, artifact.Content)
		return stageResult(protocol.StageBashOutput, "text/plain; charset=utf-8", body), nil
	}
	return protocol.GenerateResult{Artifact: artifact}, nil
}

func stageResult(stage protocol.Stage, contentType, content string) protocol.GenerateResult {
	return protocol.GenerateResult{StageOutput: &protocol.StageOutput{
		Stage: stage, ContentType: contentType, Content: content,
	}}
}

func validateNormalizedRequest(value string) error {
	if strings.TrimSpace(value) == "" {
		return errors.New("resposta vazia")
	}
	if !strings.Contains(value, "canonical_instruction:") {
		return errors.New("canonical_instruction ausente")
	}
	if !strings.Contains(value, "status:") {
		return errors.New("status ausente")
	}
	if !strings.Contains(value, "NORMALIZATION_STATUS_READY") &&
		!strings.Contains(value, "NORMALIZATION_STATUS_MISSING_INFORMATION") &&
		!strings.Contains(value, "NORMALIZATION_STATUS_UNSUPPORTED") {
		return errors.New("status de normalização desconhecido")
	}
	if strings.Contains(value, "NORMALIZATION_STATUS_READY") && !strings.Contains(value, "tasks {") {
		return errors.New("NormalizedRequest READY sem tarefas")
	}
	return nil
}

func normalizationStatus(value string) string {
	for _, status := range []string{
		"NORMALIZATION_STATUS_READY",
		"NORMALIZATION_STATUS_MISSING_INFORMATION",
		"NORMALIZATION_STATUS_UNSUPPORTED",
	} {
		if strings.Contains(value, status) {
			return status
		}
	}
	return "UNKNOWN"
}

func buildGeneratorInput(normalized, candidates string) string {
	return fmt.Sprintf(`NormalizedRequest:
%s

Capability candidates retrieved from PostgreSQL:
%s

Generate the requested Bash source using the normalized tasks as the source of truth.
Reuse an existing capability only when the candidate clearly matches the required behavior.
Do not omit any normalized task.
`, normalized, candidates)
}

func buildRepairPrompt(normalized, candidates string, validationErr error) string {
	errorText := "falha de validação desconhecida"
	if validationErr != nil {
		errorText = truncateForPrompt(validationErr.Error(), 1200)
	}
	return fmt.Sprintf(`The previous Bash generation was invalid.

NormalizedRequest:
%s

Capability candidates:
%s

bash -n validation error:
%s

Generate the script again FROM SCRATCH.
Return only valid Bash source code.
Preserve every normalized task.
Make sure the result passes: bash -n
`, normalized, candidates, errorText)
}

func truncateForPrompt(value string, maxRunes int) string {
	runes := []rune(value)
	if len(runes) <= maxRunes {
		return value
	}
	return string(runes[:maxRunes]) + "..."
}

func validateBash(ctx context.Context, content string) error {
	cmd := exec.CommandContext(ctx, "bash", "-n", "-c", content)
	if data, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("bash -n falhou: %w: %s", err, strings.TrimSpace(string(data)))
	}
	return nil
}

func cleanGeneratedBash(content string) string {
	content = strings.TrimSpace(content)
	if strings.HasPrefix(content, "```") {
		if i := strings.IndexByte(content, '\n'); i >= 0 {
			content = content[i+1:]
		}
		content = strings.TrimSpace(content)
		if strings.HasSuffix(content, "```") {
			content = strings.TrimSpace(strings.TrimSuffix(content, "```"))
		}
	}
	if i := strings.Index(content, "#!"); i > 0 {
		content = content[i:]
	}
	if !strings.HasPrefix(content, "#!") {
		content = "#!/usr/bin/env bash\n" + content
	}
	if !strings.HasSuffix(content, "\n") {
		content += "\n"
	}
	return content
}

const normalizerSystemPrompt = `You are the request-normalizer for ai-bash-gen.

Convert the user's request, written in any human language, into a structured NormalizedRequest.
Return ONLY protobuf text for ai_bash_gen.v1.NormalizedRequest.

Rules:
- Write semantic instructions and descriptions in English.
- Preserve literal values exactly as supplied by the user.
- Split the request into small logical tasks.
- Each task must have a unique snake_case id and exactly one named output.
- Use result_ref when a task consumes a previous result.
- Use depends_on only for control dependencies.
- Keep all tasks implementation-independent.
- Do not choose Bash commands, programs, capabilities, packages, databases or tools.
- Do not generate Bash.
- Do not execute anything.
- Do not invent missing values.
- If required information is missing, set status: NORMALIZATION_STATUS_MISSING_INFORMATION and populate missing_inputs.
- Otherwise set status: NORMALIZATION_STATUS_READY.
- canonical_instruction must describe the complete requested goal in English.
- final_output_ref must reference the final task output.
- For simple scalar values use DATA_KIND_TEXT unless a more specific DataKind is evident.
- Use DATA_KIND_PATH for filesystem paths.
- Return no Markdown and no explanation.

Minimal shape:
intent: "..."
canonical_instruction: "..."
input_description: "..."
output_description: "..."
tasks {
  id: "..."
  instruction: "..."
  input_description: "..."
  output_description: "..."
  output {
    name: "..."
    contract {
      kind: DATA_KIND_TEXT
      encoding: STREAM_ENCODING_TEXT_UTF8
    }
  }
}
final_output_ref: "..."
status: NORMALIZATION_STATUS_READY
`

const generatorSystemPrompt = `You are the bash-generator for ai-bash-gen.

Input is a validated NormalizedRequest plus capability candidates retrieved from the local Capability Catalog.

Return only Bash source code. Do not use Markdown fences and do not add explanations.

Rules:
- Treat the NormalizedRequest tasks as the source of truth.
- Preserve every requested transformation and final output.
- Prefer compatible reusable behavior represented by capability candidates.
- Never invent data that is absent from the request.
- Target Debian/Linux and Bash.
- Start with #!/usr/bin/env bash.
- Prefer set -Eeuo pipefail when compatible with the requested behavior.
- Quote variable expansions and paths safely.
- Do not execute the script; only return its source.
- Avoid destructive operations unless explicitly requested.
- The returned source must pass bash -n.
`
