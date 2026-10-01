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

type Runner struct {
	completer Completer
	timeout   time.Duration
}

func NewRunner(completer Completer, timeout time.Duration) *Runner {
	return &Runner{completer: completer, timeout: timeout}
}

func (r *Runner) Generate(ctx context.Context, request protocol.GenerateRequest, progress func(protocol.Stage, protocol.ProgressState, string) error) (protocol.BashArtifact, error) {
	if r.completer == nil {
		return protocol.BashArtifact{}, errors.New("completer não configurado")
	}
	if strings.TrimSpace(request.Text) == "" {
		return protocol.BashArtifact{}, errors.New("instrução vazia")
	}

	ctx, cancel := context.WithTimeout(ctx, r.timeout)
	defer cancel()
	logger := observability.Logger(ctx).With("component", "pipeline")
	pipelineStarted := time.Now()
	logger.Debug("pipeline iniciado",
		"event", "pipeline_start",
		"timeout_ms", r.timeout.Milliseconds(),
		"requested_filename", request.RequestedFilename,
		"max_generation_attempts", maxGenerationAttempts,
	)

	if err := progress(protocol.StageRequestNormalizer, protocol.StateStarted, "normalizando solicitação"); err != nil {
		return protocol.BashArtifact{}, err
	}
	normalized := strings.TrimSpace(request.Text)
	logger.Debug("solicitação normalizada",
		"event", "request_normalized",
		"input_chars", len([]rune(request.Text)),
		"normalized_chars", len([]rune(normalized)),
	)
	if err := progress(protocol.StageRequestNormalizer, protocol.StateCompleted, "solicitação normalizada"); err != nil {
		return protocol.BashArtifact{}, err
	}

	if err := progress(protocol.StageSearchCapabilities, protocol.StateStarted, "avaliando capabilities disponíveis"); err != nil {
		return protocol.BashArtifact{}, err
	}
	// O catálogo PostgreSQL/MCP ainda não está conectado ao pipeline mínimo.
	// O log abaixo é intencional: deixa explícito que nenhuma consulta foi
	// executada, evitando interpretar esta etapa como uma busca real.
	logger.Warn("consulta ao catálogo de capabilities não executada",
		"event", "database_stage_not_implemented",
		"stage", "search-capabilities",
		"database", "postgresql",
		"database_query_executed", false,
		"capability_catalog", "in_development",
	)
	if err := progress(protocol.StageSearchCapabilities, protocol.StateCompleted, "EM DESENVOLVIMENTO: PostgreSQL/Capability Catalog ainda não conectado; consulta ao banco não executada"); err != nil {
		return protocol.BashArtifact{}, err
	}

	var content string
	var validationErr error

	for attempt := 1; attempt <= maxGenerationAttempts; attempt++ {
		generatorMessage := "gerando script Bash com llama-server"
		userPrompt := normalized
		if attempt > 1 {
			generatorMessage = fmt.Sprintf("regenerando script Bash após falha de validação (tentativa %d/%d)", attempt, maxGenerationAttempts)
			userPrompt = buildRepairPrompt(normalized, validationErr)
		}

		if err := progress(protocol.StageBashGenerator, protocol.StateStarted, generatorMessage); err != nil {
			return protocol.BashArtifact{}, err
		}

		logger.Info("tentativa de geração iniciada",
			"event", "generation_attempt_start",
			"attempt", attempt,
			"max_attempts", maxGenerationAttempts,
			"repair", attempt > 1,
		)
		logger.Debug("enviando solicitação ao llama-server",
			"event", "llama_generation_start",
			"attempt", attempt,
			"system_prompt_chars", len([]rune(generatorSystemPrompt)),
			"user_prompt_chars", len([]rune(userPrompt)),
		)

		generated, err := r.completer.Complete(ctx, generatorSystemPrompt, userPrompt)
		if err != nil {
			_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
			return protocol.BashArtifact{}, fmt.Errorf("bash-generator tentativa %d/%d: %w", attempt, maxGenerationAttempts, err)
		}

		logger.Debug("resposta recebida do llama-server",
			"event", "llama_generation_response",
			"attempt", attempt,
			"raw_response_chars", len([]rune(generated)),
			"raw_response_bytes", len(generated),
		)

		content = cleanGeneratedBash(generated)
		if strings.TrimSpace(content) == "" {
			err := errors.New("modelo retornou script vazio")
			_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
			return protocol.BashArtifact{}, err
		}

		if err := progress(protocol.StageBashGenerator, protocol.StateCompleted, fmt.Sprintf("script Bash gerado (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
			return protocol.BashArtifact{}, err
		}

		if err := progress(protocol.StageValidation, protocol.StateStarted, fmt.Sprintf("validando sintaxe com bash -n (tentativa %d/%d)", attempt, maxGenerationAttempts)); err != nil {
			return protocol.BashArtifact{}, err
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
				return protocol.BashArtifact{}, err
			}
			break
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
		return protocol.BashArtifact{}, fmt.Errorf("script Bash inválido após %d tentativas: %w", maxGenerationAttempts, validationErr)
	}

	if validationErr != nil {
		return protocol.BashArtifact{}, fmt.Errorf("script Bash não validado: %w", validationErr)
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
Keep it minimal and focused on the original request.
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

const generatorSystemPrompt = `You generate Bash scripts for ai-bash-gen.

Return only the Bash source code. Do not use Markdown fences and do not add explanations.

Rules:
- Target Debian/Linux and Bash.
- Start with #!/usr/bin/env bash.
- Prefer set -Eeuo pipefail when it does not conflict with the requested behavior.
- Quote variable expansions and paths safely.
- Do not execute the script; only return its source.
- Do not invent paths, credentials, hosts, filenames, or destructive intent that the user did not provide.
- Avoid destructive operations unless the user explicitly requested them.
- Keep the script focused on the requested task.
- For simple requests, generate the smallest correct script; do not add menus, helper functions, arguments or documentation unless requested.
- The returned source must pass bash -n.
`
