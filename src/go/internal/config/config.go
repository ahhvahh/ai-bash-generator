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
	DefaultContextSize    = 32768
	DefaultStartupTimeout = 2 * time.Minute
	DefaultRequestTimeout = 10 * time.Minute
	DefaultMaxTokens      = 4096
	DefaultTemperature    = 0.2
)

type Config struct {
	Llama      LlamaConfig    `json:"llama"`
	Normalizer AgentConfig    `json:"normalizer"`
	Generator  AgentConfig    `json:"generator"`
	Database   DatabaseConfig `json:"database"`
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

type AgentConfig struct {
	Model       string  `json:"model"`
	MaxTokens   int     `json:"max_tokens"`
	Temperature float64 `json:"temperature"`
}

type DatabaseConfig struct {
	Enabled     bool   `json:"enabled"`
	Host        string `json:"host"`
	Port        int    `json:"port"`
	Name        string `json:"name"`
	User        string `json:"user"`
	SearchLimit int    `json:"search_limit"`
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

	cfg.applyAgentDefaults()
	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func defaults() Config {
	return Config{
		Llama: LlamaConfig{
			ContextSize:    DefaultContextSize,
			StartupTimeout: DefaultStartupTimeout.String(),
			RequestTimeout: DefaultRequestTimeout.String(),
			MaxTokens:      DefaultMaxTokens,
			Temperature:    DefaultTemperature,
		},
		Normalizer: AgentConfig{MaxTokens: 1200, Temperature: 0.1},
		Generator:  AgentConfig{MaxTokens: DefaultMaxTokens, Temperature: DefaultTemperature},
		Database: DatabaseConfig{
			Enabled:     true,
			Host:        "/var/run/postgresql",
			Port:        5432,
			Name:        "ai-bash-gen",
			User:        "ai-bash-gen",
			SearchLimit: 8,
		},
	}
}

func (c *Config) applyAgentDefaults() {
	if strings.TrimSpace(c.Normalizer.Model) == "" {
		c.Normalizer.Model = c.Llama.Model
	}
	if c.Normalizer.MaxTokens <= 0 {
		c.Normalizer.MaxTokens = 1200
	}
	if strings.TrimSpace(c.Generator.Model) == "" {
		c.Generator.Model = c.Llama.Model
	}
	if c.Generator.MaxTokens <= 0 {
		c.Generator.MaxTokens = c.Llama.MaxTokens
	}
	if c.Generator.Temperature == 0 && c.Llama.Temperature != 0 {
		c.Generator.Temperature = c.Llama.Temperature
	}
	if c.Database.Port == 0 {
		c.Database.Port = 5432
	}
	if strings.TrimSpace(c.Database.Host) == "" {
		c.Database.Host = "/var/run/postgresql"
	}
	if strings.TrimSpace(c.Database.Name) == "" {
		c.Database.Name = "ai-bash-gen"
	}
	if strings.TrimSpace(c.Database.User) == "" {
		c.Database.User = "ai-bash-gen"
	}
	if c.Database.SearchLimit <= 0 {
		c.Database.SearchLimit = 8
	}
}

// parseYAMLSubset intentionally supports only scalar keys used by the bootstrap
// runtime configuration. Unknown sections/keys are ignored to preserve
// forward-compatibility with richer agent configuration files.
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

		key, value, ok := strings.Cut(trimmed, ":")
		if !ok {
			return fmt.Errorf("configuração YAML linha %d: esperado 'chave: valor'", lineNo)
		}
		key = strings.TrimSpace(key)
		value = cleanScalar(strings.TrimSpace(value))

		switch section {
		case "llama":
			if err := parseLlamaField(lineNo, key, value, &cfg.Llama); err != nil {
				return err
			}
		case "normalizer":
			if err := parseAgentField(lineNo, key, value, &cfg.Normalizer); err != nil {
				return err
			}
		case "generator":
			if err := parseAgentField(lineNo, key, value, &cfg.Generator); err != nil {
				return err
			}
		case "database":
			if err := parseDatabaseField(lineNo, key, value, &cfg.Database); err != nil {
				return err
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("ler configuração YAML: %w", err)
	}
	return nil
}

func parseLlamaField(lineNo int, key, value string, cfg *LlamaConfig) error {
	switch key {
	case "binary":
		cfg.Binary = value
	case "model":
		cfg.Model = value
	case "context_size":
		n, err := strconv.Atoi(value)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: context_size inválido", lineNo) }
		cfg.ContextSize = n
	case "startup_timeout":
		cfg.StartupTimeout = value
	case "request_timeout":
		cfg.RequestTimeout = value
	case "max_tokens":
		n, err := strconv.Atoi(value)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: max_tokens inválido", lineNo) }
		cfg.MaxTokens = n
	case "temperature":
		n, err := strconv.ParseFloat(value, 64)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: temperature inválida", lineNo) }
		cfg.Temperature = n
	}
	return nil
}

func parseAgentField(lineNo int, key, value string, cfg *AgentConfig) error {
	switch key {
	case "model":
		cfg.Model = value
	case "max_tokens":
		n, err := strconv.Atoi(value)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: max_tokens inválido", lineNo) }
		cfg.MaxTokens = n
	case "temperature":
		n, err := strconv.ParseFloat(value, 64)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: temperature inválida", lineNo) }
		cfg.Temperature = n
	}
	return nil
}

func parseDatabaseField(lineNo int, key, value string, cfg *DatabaseConfig) error {
	switch key {
	case "enabled":
		v, err := strconv.ParseBool(value)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: database.enabled inválido", lineNo) }
		cfg.Enabled = v
	case "host":
		cfg.Host = value
	case "port":
		n, err := strconv.Atoi(value)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: database.port inválido", lineNo) }
		cfg.Port = n
	case "name":
		cfg.Name = value
	case "user":
		cfg.User = value
	case "search_limit":
		n, err := strconv.Atoi(value)
		if err != nil { return fmt.Errorf("configuração YAML linha %d: database.search_limit inválido", lineNo) }
		cfg.SearchLimit = n
	}
	return nil
}

func cleanScalar(value string) string {
	if value == "" {
		return ""
	}
	if strings.HasPrefix(value, "\"") && strings.HasSuffix(value, "\"") {
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
	if strings.TrimSpace(c.Normalizer.Model) == "" {
		problems = append(problems, "normalizer.model não definido")
	} else if !filepath.IsAbs(c.Normalizer.Model) {
		problems = append(problems, "normalizer.model deve ser caminho absoluto")
	}
	if strings.TrimSpace(c.Generator.Model) == "" {
		problems = append(problems, "generator.model não definido")
	} else if !filepath.IsAbs(c.Generator.Model) {
		problems = append(problems, "generator.model deve ser caminho absoluto")
	}
	if c.Llama.ContextSize <= 0 {
		problems = append(problems, "llama.context_size deve ser maior que zero")
	}
	if c.Normalizer.MaxTokens <= 0 {
		problems = append(problems, "normalizer.max_tokens deve ser maior que zero")
	}
	if c.Generator.MaxTokens <= 0 {
		problems = append(problems, "generator.max_tokens deve ser maior que zero")
	}
	if c.Normalizer.Temperature < 0 || c.Normalizer.Temperature > 2 {
		problems = append(problems, "normalizer.temperature deve estar entre 0 e 2")
	}
	if c.Generator.Temperature < 0 || c.Generator.Temperature > 2 {
		problems = append(problems, "generator.temperature deve estar entre 0 e 2")
	}
	if c.Database.Enabled {
		if strings.TrimSpace(c.Database.Name) == "" { problems = append(problems, "database.name não definido") }
		if strings.TrimSpace(c.Database.User) == "" { problems = append(problems, "database.user não definido") }
		if c.Database.Port <= 0 || c.Database.Port > 65535 { problems = append(problems, "database.port inválido") }
		if c.Database.SearchLimit <= 0 { problems = append(problems, "database.search_limit deve ser maior que zero") }
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

func (c Config) NormalizerLlama() LlamaConfig {
	out := c.Llama
	out.Model = c.Normalizer.Model
	out.MaxTokens = c.Normalizer.MaxTokens
	out.Temperature = c.Normalizer.Temperature
	return out
}

func (c Config) GeneratorLlama() LlamaConfig {
	out := c.Llama
	out.Model = c.Generator.Model
	out.MaxTokens = c.Generator.MaxTokens
	out.Temperature = c.Generator.Temperature
	return out
}
