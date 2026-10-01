package llama

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/config"
)

const modelAlias = "ai-bash-gen"

type Process struct {
	cfg        config.LlamaConfig
	socketPath string
	alias      string
	client     *Client

	mu     sync.Mutex
	cmd    *exec.Cmd
	waitCh chan error
}

func NewProcess(cfg config.LlamaConfig, socketPath string) *Process {
	return NewNamedProcess(cfg, socketPath, modelAlias)
}

func NewNamedProcess(cfg config.LlamaConfig, socketPath, alias string) *Process {
	if alias == "" {
		alias = modelAlias
	}
	return &Process{
		cfg:        cfg,
		socketPath: socketPath,
		alias:      alias,
		client:     NewClient(socketPath, alias, cfg.MaxTokens, cfg.Temperature),
	}
}

func (p *Process) Client() *Client { return p.client }

func (p *Process) Start(ctx context.Context, startupTimeout time.Duration) error {
	started := time.Now()
	if err := os.MkdirAll(filepath.Dir(p.socketPath), 0700); err != nil {
		return fmt.Errorf("criar diretório interno: %w", err)
	}
	if err := os.Remove(p.socketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remover socket llama antigo: %w", err)
	}

	verbosity := llamaLogVerbosity()
	args := llamaServerArgsNamed(p.cfg, p.socketPath, verbosity, p.alias)
	cmd := exec.Command(p.cfg.Binary, args...)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr

	slog.Debug("iniciando llama-server",
		"event", "llama_process_start",
		"binary", p.cfg.Binary,
		"socket", p.socketPath,
		"model", p.cfg.Model,
		"agent", p.alias,
		"context_size", p.cfg.ContextSize,
		"log_verbosity", verbosity,
		"reasoning", "off",
		"args", args,
	)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("iniciar llama-server: %w", err)
	}

	p.mu.Lock()
	p.cmd = cmd
	p.waitCh = make(chan error, 1)
	waitCh := p.waitCh
	p.mu.Unlock()

	go func() {
		waitCh <- cmd.Wait()
		close(waitCh)
	}()

	slog.Info("llama-server iniciado",
		"event", "llama_process_started",
		"pid", cmd.Process.Pid,
		"socket", p.socketPath,
		"model", p.cfg.Model,
		"agent", p.alias,
		"log_verbosity", verbosity,
		"reasoning", "off",
	)

	deadlineCtx, cancel := context.WithTimeout(ctx, startupTimeout)
	defer cancel()

	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()

	attempt := 0
	for {
		attempt++
		healthCtx, healthCancel := context.WithTimeout(deadlineCtx, 2*time.Second)
		err := p.client.Health(healthCtx)
		healthCancel()
		if err == nil {
			slog.Info("llama-server pronto",
				"event", "llama_process_ready",
				"socket", p.socketPath,
				"startup_duration_ms", time.Since(started).Milliseconds(),
				"health_attempts", attempt,
			)
			return nil
		}

		slog.Debug("aguardando llama-server ficar pronto",
			"event", "llama_process_waiting",
			"attempt", attempt,
			"elapsed_ms", time.Since(started).Milliseconds(),
			"error", err,
		)

		select {
		case waitErr, ok := <-waitCh:
			if !ok {
				waitErr = errors.New("processo encerrado")
			}
			return fmt.Errorf("llama-server encerrou antes de ficar pronto: %v", waitErr)
		case <-deadlineCtx.Done():
			_ = p.Close()
			return fmt.Errorf("llama-server não ficou pronto em %s: %w", startupTimeout, deadlineCtx.Err())
		case <-ticker.C:
		}
	}
}

func (p *Process) Close() error {
	p.mu.Lock()
	cmd := p.cmd
	waitCh := p.waitCh
	p.cmd = nil
	p.waitCh = nil
	p.mu.Unlock()

	if cmd == nil || cmd.Process == nil {
		return nil
	}

	slog.Debug("encerrando llama-server", "event", "llama_process_stop", "pid", cmd.Process.Pid)
	_ = cmd.Process.Signal(syscall.SIGTERM)
	if waitCh != nil {
		select {
		case err := <-waitCh:
			if err != nil {
				var exitErr *exec.ExitError
				if !errors.As(err, &exitErr) {
					return err
				}
			}
		case <-time.After(5 * time.Second):
			slog.Warn("llama-server não encerrou no prazo; enviando kill", "event", "llama_process_kill", "pid", cmd.Process.Pid)
			_ = cmd.Process.Kill()
			<-waitCh
		}
	}

	if err := os.Remove(p.socketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	slog.Info("llama-server encerrado", "event", "llama_process_stopped")
	return nil
}

func llamaServerArgs(cfg config.LlamaConfig, socketPath string, verbosity int) []string {
	return llamaServerArgsNamed(cfg, socketPath, verbosity, modelAlias)
}

func llamaServerArgsNamed(cfg config.LlamaConfig, socketPath string, verbosity int, alias string) []string {
	return []string{
		"--host", socketPath,
		"--model", cfg.Model,
		"--ctx-size", strconv.Itoa(cfg.ContextSize),
		"--alias", alias,
		"--no-webui",
		"--reasoning", "off",
		"--log-verbosity", strconv.Itoa(verbosity),
		"--log-prefix",
		"--log-timestamps",
	}
}

func llamaLogVerbosity() int {
	value := os.Getenv("AI_BASH_GEN_LLAMA_LOG_VERBOSITY")
	if value == "" {
		return 5
	}
	n, err := strconv.Atoi(value)
	if err != nil || n < 0 || n > 5 {
		slog.Warn("AI_BASH_GEN_LLAMA_LOG_VERBOSITY inválido; usando debug=5", "value", value)
		return 5
	}
	return n
}
