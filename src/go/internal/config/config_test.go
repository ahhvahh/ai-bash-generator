package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLoadYAMLRuntimeConfig(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	data := []byte(`llama:
  binary: /opt/ai-bash-gen/llama-server
  model: /var/lib/ai-bash-gen/models/test.gguf
  context_size: 1024
  startup_timeout: 45s
  request_timeout: 90s
  max_tokens: 512
  temperature: 0.1
`)
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}

	cfg, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Llama.Binary != "/opt/ai-bash-gen/llama-server" {
		t.Fatalf("binary=%q", cfg.Llama.Binary)
	}
	if cfg.Llama.Model != "/var/lib/ai-bash-gen/models/test.gguf" {
		t.Fatalf("model=%q", cfg.Llama.Model)
	}
	if cfg.Llama.ContextSize != 1024 || cfg.Llama.MaxTokens != 512 {
		t.Fatalf("config numérica inesperada: %#v", cfg.Llama)
	}
	if got, _ := cfg.StartupTimeout(); got != 45*time.Second {
		t.Fatalf("startup timeout=%s", got)
	}
}

func TestLoadJSONCompatibleConfig(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	data := []byte(`{
  "llama": {
    "binary": "/usr/local/lib/ai-bash-gen/llama-server",
    "model": "/var/lib/ai-bash-gen/models/test.gguf"
  }
}`)
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	cfg, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Llama.ContextSize != DefaultContextSize {
		t.Fatalf("default context_size=%d", cfg.Llama.ContextSize)
	}
}

func TestLoadRejectsMissingRuntimeDependencies(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte("# configuração antiga\\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(path); err == nil {
		t.Fatal("esperava erro para configuração sem llama.binary/model")
	}
}
