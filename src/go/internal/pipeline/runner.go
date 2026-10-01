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

	"github.com/ahhvahh/ai-bash-generator/internal/output"
	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

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

	if err := progress(protocol.StageRequestNormalizer, protocol.StateStarted, "normalizando solicitação"); err != nil {
		return protocol.BashArtifact{}, err
	}
	normalized := strings.TrimSpace(request.Text)
	if err := progress(protocol.StageRequestNormalizer, protocol.StateCompleted, "solicitação normalizada"); err != nil {
		return protocol.BashArtifact{}, err
	}

	if err := progress(protocol.StageSearchCapabilities, protocol.StateStarted, "avaliando capabilities disponíveis"); err != nil {
		return protocol.BashArtifact{}, err
	}
	// O catálogo MCP ainda não está ligado ao caminho mínimo funcional. A
	// geração continua sem capabilities externas, de forma explícita, para
	// manter o serviço utilizável enquanto o catálogo é implementado.
	if err := progress(protocol.StageSearchCapabilities, protocol.StateCompleted, "nenhuma capability externa requerida no pipeline mínimo"); err != nil {
		return protocol.BashArtifact{}, err
	}

	if err := progress(protocol.StageBashGenerator, protocol.StateStarted, "gerando script Bash com llama-server"); err != nil {
		return protocol.BashArtifact{}, err
	}
	content, err := r.completer.Complete(ctx, generatorSystemPrompt, normalized)
	if err != nil {
		_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
		return protocol.BashArtifact{}, fmt.Errorf("bash-generator: %w", err)
	}
	content = cleanGeneratedBash(content)
	if strings.TrimSpace(content) == "" {
		err := errors.New("modelo retornou script vazio")
		_ = progress(protocol.StageBashGenerator, protocol.StateFailed, err.Error())
		return protocol.BashArtifact{}, err
	}
	if err := progress(protocol.StageBashGenerator, protocol.StateCompleted, "script Bash gerado"); err != nil {
		return protocol.BashArtifact{}, err
	}

	if err := progress(protocol.StageValidation, protocol.StateStarted, "validando sintaxe com bash -n"); err != nil {
		return protocol.BashArtifact{}, err
	}
	if err := validateBash(ctx, content); err != nil {
		_ = progress(protocol.StageValidation, protocol.StateFailed, err.Error())
		return protocol.BashArtifact{}, err
	}
	if err := progress(protocol.StageValidation, protocol.StateCompleted, "bash -n aprovado"); err != nil {
		return protocol.BashArtifact{}, err
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
	if err := progress(protocol.StageBashOutput, protocol.StateCompleted, "artefato Bash pronto"); err != nil {
		return protocol.BashArtifact{}, err
	}
	return artifact, nil
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
`
