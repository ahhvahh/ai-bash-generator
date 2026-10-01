package config

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	DefaultContextSize    = 2048
	DefaultStartupTimeout = 2 * time.Minute
	DefaultRequestTimeout = 3 * time.Minute
	DefaultMaxTokens      = 1536
	DefaultTemperature    = 0.2
)

type Config struct {
	Llama LlamaConfig `json:"llama"`
}

type LlamaConfig struct {
	Binary         string  `json:"binary"`
	Model          string  `json:"model"`
	ContextSize    int     `json:"context_size"`
	StartupTimeout string  `json:"startup_timeout"`
	RequestTimeout string  `json:"request_timeout"`
	MaxTokens      int     `json:"max_tokens"`
	Temperature    float64 `json:"temperature"`
}

func Load(path string) (Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Config{}, fmt.Errorf("ler configuração %s: %w", path, err)
	}

	cfg := defaults()
	trimmed := bytes.TrimSpace(data)
	if len(trimmed) == 0 {
		return Config{}, errors.New("arquivo de configuração vazio")
	}

	if json.Valid(trimmed) {
		if err := json.Unmarshal(trimmed, &cfg); err != nil {
			return Config{}, fmt.Errorf("decodificar configuração JSON/YAML: %w", err)
		}
	} else if err := parseYAMLSubset(trimmed, &cfg); err != nil {
		return Config{}, err
	}

	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func defaults() Config {
	return Config{Llama: LlamaConfig{
		ContextSize:    DefaultContextSize,
		StartupTimeout: DefaultStartupTimeout.String(),
		RequestTimeout: DefaultRequestTimeout.String(),
		MaxTokens:      DefaultMaxTokens,
		Temperature:    DefaultTemperature,
	}}
}

// parseYAMLSubset intentionally supports only scalar keys used by the runtime
// configuration. JSON remains accepted because JSON is a valid YAML subset.
// Unknown top-level sections are ignored so future configuration can evolve
// without breaking this bootstrap loader.
func parseYAMLSubset(data []byte, cfg *Config) error {
	scanner := bufio.NewScanner(bytes.NewReader(data))
	section := ""
	lineNo := 0

	for scanner.Scan() {
		lineNo++
		raw := scanner.Text()
		trimmed := strings.TrimSpace(raw)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		indent := len(raw) - len(strings.TrimLeft(raw, " 	"))
		if indent == 0 {
			if !strings.HasSuffix(trimmed, ":") {
				return fmt.Errorf("configuração YAML linha %d: esperado bloco '<nome>:'", lineNo)
			}
			section = strings.TrimSpace(strings.TrimSuffix(trimmed, ":"))
			continue
		}

		if section != "llama" {
			continue
		}

		key, value, ok := strings.Cut(trimmed, ":")
		if !ok {
			return fmt.Errorf("configuração YAML linha %d: esperado 'chave: valor'", lineNo)
		}
		key = strings.TrimSpace(key)
		value = cleanScalar(strings.TrimSpace(value))

		switch key {
		case "binary":
			cfg.Llama.Binary = value
		case "model":
			cfg.Llama.Model = value
		case "context_size":
			n, err := strconv.Atoi(value)
			if err != nil {
				return fmt.Errorf("configuração YAML linha %d: context_size inválido", lineNo)
			}
			cfg.Llama.ContextSize = n
		case "startup_timeout":
			cfg.Llama.StartupTimeout = value
		case "request_timeout":
			cfg.Llama.RequestTimeout = value
		case "max_tokens":
			n, err := strconv.Atoi(value)
			if err != nil {
				return fmt.Errorf("configuração YAML linha %d: max_tokens inválido", lineNo)
			}
			cfg.Llama.MaxTokens = n
		case "temperature":
			n, err := strconv.ParseFloat(value, 64)
			if err != nil {
				return fmt.Errorf("configuração YAML linha %d: temperature inválida", lineNo)
			}
			cfg.Llama.Temperature = n
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("ler configuração YAML: %w", err)
	}
	return nil
}

func cleanScalar(value string) string {
	if value == "" {
		return ""
	}
	if strings.HasPrefix(value, """) && strings.HasSuffix(value, """) {
		if unquoted, err := strconv.Unquote(value); err == nil {
			return unquoted
		}
	}
	if strings.HasPrefix(value, "'") && strings.HasSuffix(value, "'") && len(value) >= 2 {
		return value[1 : len(value)-1]
	}
	if i := strings.Index(value, " #"); i >= 0 {
		value = value[:i]
	}
	return strings.TrimSpace(value)
}

func (c Config) Validate() error {
	var problems []string

	if strings.TrimSpace(c.Llama.Binary) == "" {
		problems = append(problems, "llama.binary não definido")
	} else if !filepath.IsAbs(c.Llama.Binary) {
		problems = append(problems, "llama.binary deve ser caminho absoluto")
	}
	if strings.TrimSpace(c.Llama.Model) == "" {
		problems = append(problems, "llama.model não definido")
	} else if !filepath.IsAbs(c.Llama.Model) {
		problems = append(problems, "llama.model deve ser caminho absoluto")
	}
	if c.Llama.ContextSize <= 0 {
		problems = append(problems, "llama.context_size deve ser maior que zero")
	}
	if c.Llama.MaxTokens <= 0 {
		problems = append(problems, "llama.max_tokens deve ser maior que zero")
	}
	if c.Llama.Temperature < 0 || c.Llama.Temperature > 2 {
		problems = append(problems, "llama.temperature deve estar entre 0 e 2")
	}
	if _, err := c.StartupTimeout(); err != nil {
		problems = append(problems, err.Error())
	}
	if _, err := c.RequestTimeout(); err != nil {
		problems = append(problems, err.Error())
	}

	if len(problems) != 0 {
		return fmt.Errorf("configuração inválida: %s", strings.Join(problems, "; "))
	}
	return nil
}

func (c Config) StartupTimeout() (time.Duration, error) {
	d, err := time.ParseDuration(c.Llama.StartupTimeout)
	if err != nil || d <= 0 {
		return 0, fmt.Errorf("llama.startup_timeout inválido: %q", c.Llama.StartupTimeout)
	}
	return d, nil
}

func (c Config) RequestTimeout() (time.Duration, error) {
	d, err := time.ParseDuration(c.Llama.RequestTimeout)
	if err != nil || d <= 0 {
		return 0, fmt.Errorf("llama.request_timeout inválido: %q", c.Llama.RequestTimeout)
	}
	return d, nil
}
