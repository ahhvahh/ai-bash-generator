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

	"github.com/ahhvahh/ai-bash-generator/internal/catalog"
	"github.com/ahhvahh/ai-bash-generator/internal/observability"
	"github.com/ahhvahh/ai-bash-generator/internal/output"
	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

const maxGenerationAttempts = 2

type Completer interface {
	Complete(ctx context.Context, systemPrompt, userPrompt string) (string, error)
}

type CapabilitySearcher interface {
	Search(context.Context, catalog.SearchRequest) (catalog.SearchResult, error)
}

type Runner struct {
	normalizer        Completer
	generator         Completer
	catalog           CapabilitySearcher
	normalizerTimeout time.Duration
	generatorTimeout  time.Duration
	legacy            bool
}

func NewRunner(completer Completer, timeout time.Duration) *Runner {
	return &Runner{
		generator:         completer,
		normalizerTimeout: timeout,
		generatorTimeout:  timeout,
		legacy:            true,
	}
}

func NewOrchestratedRunner(
	normalizer Completer,
	generator Completer,
	searcher CapabilitySearcher,
	normalizerTimeout time.Duration,
	generatorTimeout time.Duration,
) *Runner {
	return &Runner{
		normalizer:        normalizer,
		generator:         generator,
		catalog:           searcher,
		normalizerTimeout: normalizerTimeout,
		generatorTimeout:  generatorTimeout,
	}
}

func (r *Runner) Generate(ctx context.Context, request protocol.GenerateRequest, progress func(protocol.Stage, protocol.ProgressState, string) error) (protocol.BashArtifact, error) {
	if r.generator == nil {
		return protocol.BashArtifact{}, errors.New("bash-generator não configurado")
	}
	if !r.legacy && r.normalizer == nil {
		return protocol.BashArtifact{}, errors.New("request-normalizer não configurado")
	}
	if strings.TrimSpace(request.Text) == "" {
		return protocol.BashArtifact{}, errors.New("instrução vazia")
	}

	target := request.TargetStage
	if target == protocol.StageUnspecified {
		target = protocol.StageBashOutput
	}
	switch target {
	case protocol.StageRequestNormalizer,
		protocol.StageNormalizedRequest,
		protocol.StageSearchCapabilities,
		protocol.StageBashGenerator,
		protocol.StageValidation,
		protocol.StageBashOutput:
	default:
		return protocol.BashArtifact{}, fmt.Errorf("target_stage inválido: %d", target)
	}

	logger := observability.Logger(ctx).With("component", "pipeline")
	pipelineStarted := time.Now()
	logger.Debug("pipeline iniciado",
		"event", "pipeline_start",
		"requested_filename", request.RequestedFilename,
		"target_stage", target.String(),
		"max_generation_attempts", maxGenerationAttempts,
	)

	rawNormalized, err := r.runNormalizer(ctx, request, progress, logger)
	if err != nil {
		return protocol.BashArtifact{}, err
	}
	if target == protocol.StageRequestNormalizer {
		return stageArtifact("request-normalizer.textproto", rawNormalized), nil
	}

	normalized, err := r.validateNormalizedRequest(rawNormalized, progress, logger)
	if err != nil {
		return protocol.BashArtifact{}, err
	}
	if target == protocol.StageNormalizedRequest {
		return stageArtifact("normalized-request.textproto", normalized.Raw), nil
	}
	if normalized.Status != "NORMALIZATION_STATUS_READY" {
		return protocol.BashArtifact{}, fmt.Errorf("normalização não está pronta: status=%s", normalized.Status)
	}

	searchResult, err := r.runCapabilitySearch(ctx, normalized, progress)
	if err != nil {
		return protocol.BashArtifact{}, err
	}
	if target == protocol.StageSearchCapabilities {
		return stageArtifact("search-capabilities.textproto", searchResult.FormatTextProto()), nil
	}

	generatorInput := request.Text
	if !r.legacy {
		generatorInput = buildGeneratorInput(normalized, searchResult)
	}

	if target == protocol.StageBashGenerator {
		raw, err := r.generateOnce(ctx, generatorInput, 1, progress, logger, false)
		if err != nil {
			return protocol.BashArtifact{}, err
		}
		return stageArtifact("bash-generator.txt", raw), nil
	}

	content, err := r.generateAndValidate(ctx, generatorInput, progress, logger)
	if err != nil {
		return protocol.BashArtifact{}, err
	}
	if target == protocol.StageValidation {
		return stageArtifact("validation.sh", content), nil
	}

	if err := progress(protocol.StageBashOutput, protocol.StateStarted, "materializando artefato Bash"); err != nil {
		return protocol.BashArtifact{}, err
	}
	filename := request.RequestedFilename
	if filename == "" {
		filename = "generated.sh"
	}
	if err := output.ValidateFilename(filename); err != nil {
		_ = progress(protocol.StageBashOutput, protocol.StateFailed, err.Error())
		return protocol.BashArtifact{}, fmt.Errorf("filename final inválido: %w", err)
	}
	sum := sha256.Sum256([]byte(content))
	artifact := protocol.BashArtifact{
		Filename:       filename,
		Content:        content,
		SHA256:         hex.EncodeToString(sum[:]),
		FinalOutputRef: filename,
	}
	logger.Debug("artefato Bash materializado",
		"event", "bash_artifact_created",
		"filename", artifact.Filename,
		"content_bytes", len(artifact.Content),
		"sha256", artifact.SHA256,
	)
	if err := progress(protocol.StageBashOutput, protocol.StateCompleted, "artefato Bash pronto"); err != nil {
		return protocol.BashArtifact{}, err
	}
	logger.Info("pipeline concluído",
		"event", "pipeline_complete",
		"duration_ms", time.Since(pipelineStarted).Milliseconds(),
		"filename", artifact.Filename,
	)
	return artifact, nil
}

func (r *Runner) runNormalizer(
	ctx context.Context,
	request protocol.GenerateRequest,
	progress func(protocol.Stage, protocol.ProgressState, string) error,
	logger interface {
		Debug(string, ...any)
		Info(string, ...any)
		Error(string, ...any)
	},
) (string, error) {
	if err := progress(protocol.StageRequestNormalizer, protocol.StateStarted, "executando request-normalizer"); err != nil {
		return "", err
	}

	if r.legacy {
		raw := passthroughNormalized(request.Text).Raw
		if err := progress(protocol.StageRequestNormalizer, protocol.StateCompleted, "request-normalizer concluído (modo compatibilidade)"); err != nil {
			return "", err
		}
		return raw, nil
	}

	started := time.Now()
	callCtx, cancel := context.WithTimeout(ctx, r.normalizerTimeout)
	defer cancel()
	logger.Debug("request-normalizer iniciado",
		"event", "normalizer_llm_request_start",
		"input_chars", len([]rune(request.Text)),
	)

	raw, err := r.normalizer.Complete(callCtx, normalizerSystemPrompt, userRequestTextProto(request.Text))
	if err != nil {
		_ = progress(protocol.StageRequestNormalizer, protocol.StateFailed, err.Error())
		return "", fmt.Errorf("request-normalizer: %w", err)
	}
	raw = cleanTextProto(raw)
	if strings.TrimSpace(raw) == "" {
		err := errors.New("request-normalizer retornou conteúdo vazio")
		_ = progress(protocol.StageRequestNormalizer, protocol.StateFailed, err.Error())
		return "", err
	}

	logger.Info("request-normalizer respondeu",
		"event", "normalizer_llm_response",
		"duration_ms", time.Since(started).Milliseconds(),
		"output_chars", len([]rune(raw)),
	)
	if err := progress(protocol.StageRequestNormalizer, protocol.StateCompleted, "TextProto produzido pelo request-normalizer"); err != nil {
		return "", err
	}
	return raw, nil
}

func (r *Runner) validateNormalizedRequest(
	raw string,
	progress func(protocol.Stage, protocol.ProgressState, string) error,
	logger interface {
		Info(string, ...any)
		Error(string, ...any)
	},
) (NormalizedRequest, error) {
	if err := progress(protocol.StageNormalizedRequest, protocol.StateStarted, "validando NormalizedRequest"); err != nil {
		return NormalizedRequest{}, err
	}
	started := time.Now()
	normalized, err := parseNormalizedRequest(raw)
	if err != nil {
		_ = progress(protocol.StageNormalizedRequest, protocol.StateFailed, err.Error())
		logger.Error("NormalizedRequest inválida",
			"event", "normalized_request_validation_failed",
			"error", err,
		)
		return NormalizedRequest{}, err
	}

	logger.Info("NormalizedRequest validada",
		"event", "request_normalized",
		"duration_ms", time.Since(started).Milliseconds(),
		"normalization_status", normalized.Status,
		"task_count", len(normalized.Tasks),
		"intent", normalized.Intent,
		"normalized_chars", len([]rune(normalized.Raw)),
	)
	message := fmt.Sprintf("status=%s tasks=%d", normalized.Status, len(normalized.Tasks))
	if err := progress(protocol.StageNormalizedRequest, protocol.StateCompleted, message); err != nil {
		return NormalizedRequest{}, err
	}
	return normalized, nil
}

func (r *Runner) runCapabilitySearch(
	ctx context.Context,
	normalized NormalizedRequest,
	progress func(protocol.Stage, protocol.ProgressState, string) error,
) (catalog.SearchResult, error) {
	if err := progress(protocol.StageSearchCapabilities, protocol.StateStarted, "consultando Capability Catalog no PostgreSQL"); err != nil {
		return catalog.SearchResult{}, err
	}

	if r.catalog == nil {
		if err := progress(protocol.StageSearchCapabilities, protocol.StateCompleted, "catálogo não configurado; zero candidatos"); err != nil {
			return catalog.SearchResult{}, err
		}
		return catalog.SearchResult{}, nil
	}

	request := catalog.SearchRequest{
		Intent:               normalized.Intent,
		CanonicalInstruction: normalized.CanonicalInstruction,
		InputDescription:     normalized.InputDescription,
		OutputDescription:    normalized.OutputDescription,
	}
	for _, task := range normalized.Tasks {
		request.Tasks = append(request.Tasks, catalog.TaskQuery{
			ID:                task.ID,
			Instruction:       task.Instruction,
			InputDescription:  task.InputDescription,
			OutputDescription: task.OutputDescription,
		})
	}

	result, err := r.catalog.Search(ctx, request)
	if err != nil {
		_ = progress(protocol.StageSearchCapabilities, protocol.StateFailed, err.Error())
		return catalog.SearchResult{}, err
	}
	message := fmt.Sprintf(
		"PostgreSQL consultado: composite=%d task_queries=%d task_candidates=%d",
		len(result.Composite), len(result.Tasks), result.TaskCandidateCount(),
	)
	if err := progress(protocol.StageSearchCapabilities, protocol.StateCompleted, message); err != nil {
		return catalog.SearchResult{}, err
	}
	return result, nil
}

func (r *Runner) generateOnce(
	ctx context.Context,
	userPrompt string,
	attempt int,
	progress func(protocol.Stage, protocol.ProgressState, string) error,
	logger interface {
		Debug(string, ...any)
		Info(string, ...any)
		Error(string, ...any)
	},
	repair bool,
) (string, error) {
	message := "gerando com bash-generator"
	if repair {
		message = fmt.Sprintf("regenerando após falha de validação (tentativa %d/%d)", attempt, maxGenerationAttempts)
	}
	if err := progress(protocol.StageBashGenerator, protocol.StateStarted, message); err != nil {
		return "", err
	}

	logger.Info("tentativa de geração iniciada",
		"event", "generation_attempt_start",
		"attempt", attempt,
		"max_attempts", maxGenerationAttempts,
		"repair", repair,
	)
	logger.Debug("enviando solicitação ao bash-generator",
		"event", "generator_llm_request_start",
		"attempt", attempt,
		"user_prompt_chars", len([]rune(userPrompt)),
	)

	callCtx, cancel := context.WithTimeout(ctx, r.generatorTimeout)
	defer cancel()
	generated, err := r.generator.Complete(callCtx, generatorSystemPrompt, userPrompt)
	if err != nil {
		_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
		return "", fmt.Errorf("bash-generator tentativa %d/%d: %w", attempt, maxGenerationAttempts, err)
	}
	if strings.TrimSpace(generated) == "" {
		err := errors.New("modelo retornou conteúdo vazio")
		_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
		return "", err
	}

	logger.Debug("resposta recebida do bash-generator",
		"event", "generator_llm_response",
		"attempt", attempt,
		"raw_response_chars", len([]rune(generated)),
		"raw_response_bytes", len(generated),
	)
	if err := progress(protocol.StageBashGenerator, protocol.StateCompleted, fmt.Sprintf("resposta gerada (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
		return "", err
	}
	return generated, nil
}

func (r *Runner) generateAndValidate(
	ctx context.Context,
	basePrompt string,
	progress func(protocol.Stage, protocol.ProgressState, string) error,
	logger interface {
		Debug(string, ...any)
		Info(string, ...any)
		Warn(string, ...any)
		Error(string, ...any)
	},
) (string, error) {
	var content string
	var validationErr error

	for attempt := 1; attempt <= maxGenerationAttempts; attempt++ {
		userPrompt := basePrompt
		repair := attempt > 1
		if repair {
			userPrompt = buildRepairPrompt(basePrompt, validationErr)
		}

		generated, err := r.generateOnce(ctx, userPrompt, attempt, progress, logger, repair)
		if err != nil {
			return "", err
		}
		content = cleanGeneratedBash(generated)
		if strings.TrimSpace(content) == "" {
			return "", errors.New("modelo retornou script vazio")
		}

		if err := progress(protocol.StageValidation, protocol.StateStarted, fmt.Sprintf("validando sintaxe com bash -n (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
			return "", err
		}

		validationStarted := time.Now()
		logger.Debug("executando validação sintática",
			"event", "bash_validation_start",
			"attempt", attempt,
			"validator", "bash -n",
			"content_bytes", len(content),
		)

		validationErr = validateBash(ctx, content)
		if validationErr == nil {
			logger.Debug("validação sintática concluída",
				"event", "bash_validation_complete",
				"attempt", attempt,
				"validator", "bash -n",
				"duration_ms", time.Since(validationStarted).Milliseconds(),
			)
			if err := progress(protocol.StageValidation, protocol.StateCompleted, fmt.Sprintf("bash -n aprovado (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
				return "", err
			}
			return content, nil
		}

		logger.Warn("script gerado falhou na validação sintática",
			"event", "generation_validation_failed",
			"attempt", attempt,
			"max_attempts", maxGenerationAttempts,
			"duration_ms", time.Since(validationStarted).Milliseconds(),
			"validation_error", validationErr.Error(),
		)

		if attempt < maxGenerationAttempts {
			message := fmt.Sprintf("tentativa %d/%d falhou no bash -n; solicitando nova geração ao LLM: %s", attempt, maxGenerationAttempts, validationErr.Error())
			_ = progress(protocol.StageValidation, protocol.StateFailed, message)
			logger.Warn("nova geração solicitada ao LLM",
				"event", "generation_retry_requested",
				"failed_attempt", attempt,
				"next_attempt", attempt+1,
				"reason", "bash_validation_failed",
				"validation_error", validationErr.Error(),
			)
			continue
		}

		_ = progress(protocol.StageValidation, protocol.StateFailed, validationErr.Error())
		return "", fmt.Errorf("script Bash inválido após %d tentativas: %w", maxGenerationAttempts, validationErr)
	}
	return "", errors.New("script Bash não validado")
}

func stageArtifact(filename, content string) protocol.BashArtifact {
	return protocol.BashArtifact{
		Filename:       filename,
		Content:        content,
		FinalOutputRef: filename,
	}
}

func buildGeneratorInput(normalized NormalizedRequest, search catalog.SearchResult) string {
	return fmt.Sprintf(`NormalizedRequest:
%s

SearchCapabilitiesResponse:
%s

Generate the Bash source that fulfills the normalized request.
Capability candidates are discovery hints. Do not claim to reuse an implementation unless its implementation was actually supplied.
Preserve every normalized task and requested constraint.`,
		normalized.Raw,
		search.FormatTextProto(),
	)
}

func buildRepairPrompt(originalRequest string, validationErr error) string {
	errorText := "falha de validação desconhecida"
	if validationErr != nil {
		errorText = truncateForPrompt(validationErr.Error(), 1200)
	}
	return fmt.Sprintf(`The previous Bash generation for this request was invalid.

Original request:
%s

bash -n validation error:
%s

Generate the script again FROM SCRATCH.
Return only valid Bash source code.
Keep it focused on the request.
Do not repeat the malformed previous structure.
Make sure the result passes: bash -n
`, originalRequest, errorText)
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

const generatorSystemPrompt = `You are the bash-generator for ai-bash-gen.

The user request has already been normalized by another agent.
You may receive capability candidate summaries discovered in PostgreSQL.

Return only the Bash source code. Do not use Markdown fences and do not add explanations.

Rules:
- Target Debian/Linux and Bash.
- Start with #!/usr/bin/env bash.
- Treat NormalizedRequest as the source of truth.
- Preserve every normalized task, literal value, constraint and final result.
- Capability summaries are discovery hints only; never invent missing capability implementations.
- Prefer set -Eeuo pipefail when it does not conflict with the requested behavior.
- Quote variable expansions and paths safely.
- Do not execute the script; only return its source.
- Do not invent paths, credentials, hosts, filenames, or destructive intent that the user did not provide.
- Avoid destructive operations unless the request explicitly requires them.
- Keep the script focused on the requested task.
- The returned source must pass bash -n.
`
