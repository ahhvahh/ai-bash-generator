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
	DefaultContextSize             = 32768
	DefaultNormalizerContextSize   = 8192
	DefaultStartupTimeout          = 2 * time.Minute
	DefaultRequestTimeout          = 10 * time.Minute
	DefaultNormalizerRequestTimeout = 2 * time.Minute
	DefaultMaxTokens               = 4096
	DefaultNormalizerMaxTokens     = 1600
	DefaultTemperature             = 0.2
	DefaultNormalizerTemperature   = 0.1
	DefaultDatabaseHost            = "/var/run/postgresql"
	DefaultDatabasePort            = 5432
	DefaultDatabaseName            = "ai-bash-gen"
	DefaultDatabaseUser            = "ai-bash-gen"
	DefaultDatabaseSearchLimit     = 5
)

type Config struct {
	// Llama is the legacy single-agent configuration. It remains accepted
	// for backward compatibility and is used as fallback for missing agent
	// paths.
	Llama    LlamaConfig    `json:"llama"`
	Agents   AgentsConfig   `json:"agents"`
	Database DatabaseConfig `json:"database"`
}

type AgentsConfig struct {
	RequestNormalizer LlamaConfig `json:"request_normalizer"`
	BashGenerator     LlamaConfig `json:"bash_generator"`
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

type DatabaseConfig struct {
	Host        string `json:"host"`
	Port        int    `json:"port"`
	Name        string `json:"name"`
	User        string `json:"user"`
	Required    bool   `json:"required"`
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

	cfg.applyFallbacks()
	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func defaults() Config {
	generator := LlamaConfig{
		ContextSize:    DefaultContextSize,
		StartupTimeout: DefaultStartupTimeout.String(),
		RequestTimeout: DefaultRequestTimeout.String(),
		MaxTokens:      DefaultMaxTokens,
		Temperature:    DefaultTemperature,
	}
	normalizer := generator
	normalizer.ContextSize = DefaultNormalizerContextSize
	normalizer.RequestTimeout = DefaultNormalizerRequestTimeout.String()
	normalizer.MaxTokens = DefaultNormalizerMaxTokens
	normalizer.Temperature = DefaultNormalizerTemperature

	return Config{
		Llama: generator,
		Agents: AgentsConfig{
			RequestNormalizer: normalizer,
			BashGenerator:     generator,
		},
		Database: DatabaseConfig{
			Host:        DefaultDatabaseHost,
			Port:        DefaultDatabasePort,
			Name:        DefaultDatabaseName,
			User:        DefaultDatabaseUser,
			Required:    false,
			SearchLimit: DefaultDatabaseSearchLimit,
		},
	}
}

func (c *Config) applyFallbacks() {
	legacy := c.Llama
	if c.Agents.RequestNormalizer.Binary == "" && c.Agents.RequestNormalizer.Model == "" &&
		legacy.Binary != "" && legacy.Model != "" {
		c.Agents.RequestNormalizer = legacy
	}
	if c.Agents.BashGenerator.Binary == "" && c.Agents.BashGenerator.Model == "" &&
		legacy.Binary != "" && legacy.Model != "" {
		c.Agents.BashGenerator = legacy
	}
	fillLlamaFallbacks(&c.Agents.RequestNormalizer, legacy)
	fillLlamaFallbacks(&c.Agents.BashGenerator, legacy)

	if c.Llama.Binary == "" {
		c.Llama.Binary = c.Agents.BashGenerator.Binary
	}
	if c.Llama.Model == "" {
		c.Llama.Model = c.Agents.BashGenerator.Model
	}
	if c.Database.Host == "" {
		c.Database.Host = DefaultDatabaseHost
	}
	if c.Database.Port == 0 {
		c.Database.Port = DefaultDatabasePort
	}
	if c.Database.Name == "" {
		c.Database.Name = DefaultDatabaseName
	}
	if c.Database.User == "" {
		c.Database.User = DefaultDatabaseUser
	}
	if c.Database.SearchLimit == 0 {
		c.Database.SearchLimit = DefaultDatabaseSearchLimit
	}
}

func fillLlamaFallbacks(dst *LlamaConfig, fallback LlamaConfig) {
	if dst.Binary == "" {
		dst.Binary = fallback.Binary
	}
	if dst.Model == "" {
		dst.Model = fallback.Model
	}
	if dst.ContextSize <= 0 {
		dst.ContextSize = fallback.ContextSize
	}
	if dst.StartupTimeout == "" {
		dst.StartupTimeout = fallback.StartupTimeout
	}
	if dst.RequestTimeout == "" {
		dst.RequestTimeout = fallback.RequestTimeout
	}
	if dst.MaxTokens <= 0 {
		dst.MaxTokens = fallback.MaxTokens
	}
}

// parseYAMLSubset intentionally supports only scalar keys used by the runtime
// configuration. JSON remains accepted because JSON is a valid YAML subset.
// Unknown top-level sections are ignored so future configuration can evolve
// without breaking this bootstrap loader.
func parseYAMLSubset(data []byte, cfg *Config) error {
	scanner := bufio.NewScanner(bytes.NewReader(data))
	section := ""
	subsection := ""
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
			subsection = ""
			continue
		}

		if section == "agents" && indent <= 2 && strings.HasSuffix(trimmed, ":") {
			subsection = strings.TrimSpace(strings.TrimSuffix(trimmed, ":"))
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
			if err := assignLlamaScalar(&cfg.Llama, key, value, lineNo); err != nil {
				return err
			}
		case "agents":
			var target *LlamaConfig
			switch subsection {
			case "request_normalizer":
				target = &cfg.Agents.RequestNormalizer
			case "bash_generator":
				target = &cfg.Agents.BashGenerator
			default:
				continue
			}
			if err := assignLlamaScalar(target, key, value, lineNo); err != nil {
				return err
			}
		case "database":
			switch key {
			case "host":
				cfg.Database.Host = value
			case "port":
				n, err := strconv.Atoi(value)
				if err != nil {
					return fmt.Errorf("configuração YAML linha %d: database.port inválido", lineNo)
				}
				cfg.Database.Port = n
			case "name":
				cfg.Database.Name = value
			case "user":
				cfg.Database.User = value
			case "required":
				b, err := strconv.ParseBool(value)
				if err != nil {
					return fmt.Errorf("configuração YAML linha %d: database.required inválido", lineNo)
				}
				cfg.Database.Required = b
			case "search_limit":
				n, err := strconv.Atoi(value)
				if err != nil {
					return fmt.Errorf("configuração YAML linha %d: database.search_limit inválido", lineNo)
				}
				cfg.Database.SearchLimit = n
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("ler configuração YAML: %w", err)
	}
	return nil
}

func assignLlamaScalar(cfg *LlamaConfig, key, value string, lineNo int) error {
	switch key {
	case "binary":
		cfg.Binary = value
	case "model":
		cfg.Model = value
	case "context_size":
		n, err := strconv.Atoi(value)
		if err != nil {
			return fmt.Errorf("configuração YAML linha %d: context_size inválido", lineNo)
		}
		cfg.ContextSize = n
	case "startup_timeout":
		cfg.StartupTimeout = value
	case "request_timeout":
		cfg.RequestTimeout = value
	case "max_tokens":
		n, err := strconv.Atoi(value)
		if err != nil {
			return fmt.Errorf("configuração YAML linha %d: max_tokens inválido", lineNo)
		}
		cfg.MaxTokens = n
	case "temperature":
		n, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return fmt.Errorf("configuração YAML linha %d: temperature inválida", lineNo)
		}
		cfg.Temperature = n
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
	if strings.HasPrefix(value, "\"") && strings.HasSuffix(value, "\"") {
		return value[1 : len(value)-1]
	}
	if i := strings.Index(value, " #"); i >= 0 {
		value = value[:i]
	}
	return strings.TrimSpace(value)
}

func (c Config) Validate() error {
	var problems []string
	if err := validateLlamaConfig("agents.request_normalizer", c.Agents.RequestNormalizer); err != nil {
		problems = append(problems, err.Error())
	}
	if err := validateLlamaConfig("agents.bash_generator", c.Agents.BashGenerator); err != nil {
		problems = append(problems, err.Error())
	}
	if c.Database.Required {
		if strings.TrimSpace(c.Database.Host) == "" {
			problems = append(problems, "database.host não definido")
		}
		if c.Database.Port <= 0 || c.Database.Port > 65535 {
			problems = append(problems, "database.port inválido")
		}
		if strings.TrimSpace(c.Database.Name) == "" {
			problems = append(problems, "database.name não definido")
		}
		if strings.TrimSpace(c.Database.User) == "" {
			problems = append(problems, "database.user não definido")
		}
	}
	if c.Database.SearchLimit < 1 || c.Database.SearchLimit > 50 {
		problems = append(problems, "database.search_limit deve estar entre 1 e 50")
	}

	if len(problems) != 0 {
		return fmt.Errorf("configuração inválida: %s", strings.Join(problems, "; "))
	}
	return nil
}

func validateLlamaConfig(label string, cfg LlamaConfig) error {
	var problems []string
	if strings.TrimSpace(cfg.Binary) == "" {
		problems = append(problems, label+".binary não definido")
	} else if !filepath.IsAbs(cfg.Binary) {
		problems = append(problems, label+".binary deve ser caminho absoluto")
	}
	if strings.TrimSpace(cfg.Model) == "" {
		problems = append(problems, label+".model não definido")
	} else if !filepath.IsAbs(cfg.Model) {
		problems = append(problems, label+".model deve ser caminho absoluto")
	}
	if cfg.ContextSize <= 0 {
		problems = append(problems, label+".context_size deve ser maior que zero")
	}
	if cfg.MaxTokens <= 0 {
		problems = append(problems, label+".max_tokens deve ser maior que zero")
	}
	if cfg.Temperature < 0 || cfg.Temperature > 2 {
		problems = append(problems, label+".temperature deve estar entre 0 e 2")
	}
	if _, err := cfg.StartupDuration(); err != nil {
		problems = append(problems, label+"."+err.Error())
	}
	if _, err := cfg.RequestDuration(); err != nil {
		problems = append(problems, label+"."+err.Error())
	}
	if len(problems) != 0 {
		return errors.New(strings.Join(problems, "; "))
	}
	return nil
}

func (c Config) NormalizerConfig() LlamaConfig {
	cfg := c.Agents.RequestNormalizer
	if cfg.Binary == "" && cfg.Model == "" {
		cfg = c.Llama
	}
	fillLlamaFallbacks(&cfg, c.Llama)
	return cfg
}

func (c Config) GeneratorConfig() LlamaConfig {
	cfg := c.Agents.BashGenerator
	if cfg.Binary == "" && cfg.Model == "" {
		cfg = c.Llama
	}
	fillLlamaFallbacks(&cfg, c.Llama)
	return cfg
}

func (c Config) StartupTimeout() (time.Duration, error) {
	return c.Agents.BashGenerator.StartupDuration()
}

func (c Config) RequestTimeout() (time.Duration, error) {
	return c.Agents.BashGenerator.RequestDuration()
}

func (c LlamaConfig) StartupDuration() (time.Duration, error) {
	d, err := time.ParseDuration(c.StartupTimeout)
	if err != nil || d <= 0 {
		return 0, fmt.Errorf("startup_timeout inválido: %q", c.StartupTimeout)
	}
	return d, nil
}

func (c LlamaConfig) RequestDuration() (time.Duration, error) {
	d, err := time.ParseDuration(c.RequestTimeout)
	if err != nil || d <= 0 {
		return 0, fmt.Errorf("request_timeout inválido: %q", c.RequestTimeout)
	}
	return d, nil
}
