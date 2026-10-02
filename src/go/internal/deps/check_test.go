package deps

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/ahhvahh/ai-bash-generator/internal/config"
)

func TestValidateAcceptsCompatibleRuntime(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("teste usa script executável POSIX")
	}
	dir := t.TempDir()
	llama := filepath.Join(dir, "llama-server")
	script := "#!/usr/bin/env bash\nif [[ \"${1:-}\" == \"--help\" ]]; then echo '  --host HOST bind to UNIX socket when HOST ends with .sock'; exit 0; fi\nif [[ \"${1:-}\" == \"--version\" ]]; then echo fake; exit 0; fi\nexit 0\n"
	if err := os.WriteFile(llama, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	model := filepath.Join(dir, "model.gguf")
	if err := os.WriteFile(model, []byte("GGUF-test"), 0644); err != nil {
		t.Fatal(err)
	}

	cfg := config.Config{
		Llama: config.LlamaConfig{
			Binary: llama, Model: model, ContextSize: 1024,
			StartupTimeout: "1s", RequestTimeout: "1s",
			MaxTokens: 128, Temperature: 0.1,
		},
		Normalizer: config.AgentConfig{Model: model, MaxTokens: 64, Temperature: 0.1},
		Generator: config.AgentConfig{Model: model, MaxTokens: 128, Temperature: 0.1},
	}
	if err := Validate(cfg); err != nil {
		t.Fatal(err)
	}
}

func TestValidateRejectsMissingLlamaAndModel(t *testing.T) {
	cfg := config.Config{
		Llama: config.LlamaConfig{
			Binary: "/missing/llama-server",
			Model: "/missing/model.gguf",
			ContextSize: 1024, StartupTimeout: "1s", RequestTimeout: "1s",
			MaxTokens: 128, Temperature: 0.1,
		},
		Normalizer: config.AgentConfig{Model: "/missing/normalizer.gguf", MaxTokens: 64, Temperature: 0.1},
		Generator: config.AgentConfig{Model: "/missing/generator.gguf", MaxTokens: 128, Temperature: 0.1},
	}
	if err := Validate(cfg); err == nil {
		t.Fatal("esperava erro")
	}
}
