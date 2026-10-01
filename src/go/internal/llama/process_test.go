package llama

import (
	"strings"
	"testing"

	"github.com/ahhvahh/ai-bash-generator/internal/config"
)

func TestLlamaServerArgsDisableReasoning(t *testing.T) {
	args := llamaServerArgs(config.LlamaConfig{
		Model:       "/var/lib/ai-bash-gen/models/model.gguf",
		ContextSize: 2048,
	}, "/run/ai-bash-gen/internal/llama.sock", 5)

	joined := strings.Join(args, " ")
	if !strings.Contains(joined, "--reasoning off") {
		t.Fatalf("args sem --reasoning off: %q", joined)
	}
	if !strings.Contains(joined, "--ctx-size 2048") {
		t.Fatalf("args sem ctx-size esperado: %q", joined)
	}
}
