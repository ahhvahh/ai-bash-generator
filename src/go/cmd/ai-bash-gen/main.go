package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/buildinfo"
	"github.com/ahhvahh/ai-bash-generator/internal/catalog"
	"github.com/ahhvahh/ai-bash-generator/internal/config"
	"github.com/ahhvahh/ai-bash-generator/internal/deps"
	"github.com/ahhvahh/ai-bash-generator/internal/llama"
	"github.com/ahhvahh/ai-bash-generator/internal/observability"
	"github.com/ahhvahh/ai-bash-generator/internal/pipeline"
	"github.com/ahhvahh/ai-bash-generator/internal/platform"
	"github.com/ahhvahh/ai-bash-generator/internal/service"
)

func main() {
	observability.ConfigureFromEnv()
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	fs := flag.NewFlagSet("ai-bash-gen", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	showVersion := fs.Bool("version", false, "exibe a versão")
	showPaths := fs.Bool("show-paths", false, "exibe os caminhos padrão do serviço")
	configPath := fs.String("config", "", "inicia o serviço usando o arquivo de configuração informado")
	checkDependencies := fs.Bool("check-dependencies", false, "valida dependências de runtime sem iniciar o serviço")
	fs.Usage = func() {
		fmt.Fprintln(fs.Output(), "Uso: ai-bash-gen [--version] [--show-paths] [--config <arquivo>] [--check-dependencies]")
		fmt.Fprintln(fs.Output(), "")
		fmt.Fprintln(fs.Output(), "Modo serviço:")
		fmt.Fprintln(fs.Output(), "  ai-bash-gen --config /etc/ai-bash-gen/config.yaml")
		fmt.Fprintln(fs.Output(), "")
		fmt.Fprintln(fs.Output(), "Validação:")
		fmt.Fprintln(fs.Output(), "  ai-bash-gen --config /etc/ai-bash-gen/config.yaml --check-dependencies")
		fmt.Fprintln(fs.Output(), "")
		fs.PrintDefaults()
	}
	if err := fs.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return 0
		}
		return 2
	}
	if fs.NArg() != 0 {
		fmt.Fprintf(fs.Output(), "argumento inesperado: %s\n", fs.Arg(0))
		fs.Usage()
		return 2
	}

	switch {
	case *showVersion:
		fmt.Println(buildinfo.String())
		return 0
	case *showPaths:
		p := platform.DefaultPaths()
		fmt.Printf("config_dir=%s\n", p.ConfigDir)
		fmt.Printf("state_dir=%s\n", p.StateDir)
		fmt.Printf("runtime_dir=%s\n", p.RuntimeDir)
		fmt.Printf("routes_dir=%s\n", p.RoutesDir)
		fmt.Printf("normalizer_socket=%s\n", p.NormalizerSocket)
		fmt.Printf("generator_socket=%s\n", p.GeneratorSocket)
		fmt.Printf("llama_socket=%s\n", p.LlamaSocket)
		fmt.Printf("generate_socket=%s\n", p.GenerateSocket)
		return 0
	case *checkDependencies && *configPath == "":
		fmt.Fprintln(fs.Output(), "--check-dependencies requer --config <arquivo>")
		return 2
	case *checkDependencies:
		return runDependencyCheck(*configPath)
	case *configPath != "":
		return runDaemon(*configPath)
	default:
		fs.Usage()
		return 0
	}
}

func loadAndValidateConfig(configPath string) (config.Config, error) {
	cfg, err := config.Load(configPath)
	if err != nil {
		return config.Config{}, err
	}
	if err := deps.Validate(cfg); err != nil {
		return config.Config{}, err
	}
	return cfg, nil
}

func runDependencyCheck(configPath string) int {
	cfg, err := loadAndValidateConfig(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERRO dependências: %v\n", err)
		return 1
	}
	if cfg.Database.Required {
		db := catalog.New(cfg.Database)
		if err := db.Ping(context.Background()); err != nil {
			fmt.Fprintf(os.Stderr, "ERRO dependências: %v\n", err)
			return 1
		}
	}
	fmt.Println("dependências: OK")
	fmt.Printf("normalizer_model=%s\n", cfg.NormalizerConfig().Model)
	fmt.Printf("generator_model=%s\n", cfg.GeneratorConfig().Model)
	fmt.Printf("database_required=%t\n", cfg.Database.Required)
	if cfg.Database.Required {
		fmt.Printf("database=%s@%s:%d/%s\n", cfg.Database.User, cfg.Database.Host, cfg.Database.Port, cfg.Database.Name)
	}
	return 0
}

func runDaemon(configPath string) int {
	started := time.Now()
	slog.Info("inicializando ai-bash-gen", "event", "daemon_start", "config", configPath)
	cfg, err := loadAndValidateConfig(configPath)
	if err != nil {
		slog.Error("dependências/configuração inválidas; serviço não será iniciado", "config", configPath, "error", err)
		return 1
	}

	paths := platform.DefaultPaths()
	catalogClient := catalog.New(cfg.Database)
	if cfg.Database.Required {
		if err := catalogClient.Ping(context.Background()); err != nil {
			slog.Error("Capability Catalog/PostgreSQL indisponível; rota pública não será criada", "error", err)
			return 1
		}
		slog.Info("Capability Catalog PostgreSQL disponível",
			"event", "catalog_ready",
			"host", cfg.Database.Host,
			"port", cfg.Database.Port,
			"database", cfg.Database.Name,
			"user", cfg.Database.User,
		)
	}

	normalizerCfg := cfg.NormalizerConfig()
	generatorCfg := cfg.GeneratorConfig()
	normalizerStartupTimeout, _ := normalizerCfg.StartupDuration()
	generatorStartupTimeout, _ := generatorCfg.StartupDuration()
	normalizerRequestTimeout, _ := normalizerCfg.RequestDuration()
	generatorRequestTimeout, _ := generatorCfg.RequestDuration()

	normalizerProcess := llama.NewNamedProcess(normalizerCfg, paths.NormalizerSocket, "request-normalizer")
	if err := normalizerProcess.Start(context.Background(), normalizerStartupTimeout); err != nil {
		slog.Error("falha ao iniciar request-normalizer; rota pública não será criada", "error", err)
		return 1
	}
	defer func() {
		if err := normalizerProcess.Close(); err != nil {
			slog.Warn("falha ao encerrar request-normalizer", "error", err)
		}
	}()

	generatorProcess := llama.NewNamedProcess(generatorCfg, paths.GeneratorSocket, "bash-generator")
	if err := generatorProcess.Start(context.Background(), generatorStartupTimeout); err != nil {
		slog.Error("falha ao iniciar bash-generator; rota pública não será criada", "error", err)
		return 1
	}
	defer func() {
		if err := generatorProcess.Close(); err != nil {
			slog.Warn("falha ao encerrar bash-generator", "error", err)
		}
	}()

	generationPipeline := pipeline.NewOrchestratedRunner(
		normalizerProcess.Client(),
		generatorProcess.Client(),
		catalogClient,
		normalizerRequestTimeout,
		generatorRequestTimeout,
	)
	generationService := service.New(paths.GenerateSocket, generationPipeline)
	if err := generationService.Start(); err != nil {
		slog.Error("falha ao iniciar serviço de geração", "socket", paths.GenerateSocket, "error", err)
		return 1
	}
	defer generationService.Close()

	slog.Info("ai-bash-gen iniciado",
		"event", "daemon_ready",
		"startup_duration_ms", time.Since(started).Milliseconds(),
		"config", configPath,
		"pid", os.Getpid(),
		"normalizer_model", normalizerCfg.Model,
		"generator_model", generatorCfg.Model,
		"database_required", cfg.Database.Required,
	)
	slog.Info("caminhos do serviço",
		"state_dir", paths.StateDir,
		"runtime_dir", paths.RuntimeDir,
		"routes_dir", paths.RoutesDir,
		"normalizer_socket", paths.NormalizerSocket,
		"generator_socket", paths.GeneratorSocket,
		"generate_socket", paths.GenerateSocket,
	)

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)
	sig := <-signals
	slog.Info("sinal de encerramento recebido", "signal", sig.String())
	slog.Info("ai-bash-gen encerrado")
	return 0
}
