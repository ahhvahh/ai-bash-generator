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
	client     *Client

	mu     sync.Mutex
	cmd    *exec.Cmd
	waitCh chan error
}

func NewProcess(cfg config.LlamaConfig, socketPath string) *Process {
	return &Process{
		cfg: cfg,
		socketPath: socketPath,
		client: NewClient(socketPath, modelAlias, cfg.MaxTokens, cfg.Temperature),
	}
}

func (p *Process) Client() *Client { return p.client }

func (p *Process) Start(ctx context.Context, startupTimeout time.Duration) error {
	if err := os.MkdirAll(filepath.Dir(p.socketPath), 0700); err != nil {
		return fmt.Errorf("criar diretório interno: %w", err)
	}
	if err := os.Remove(p.socketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remover socket llama antigo: %w", err)
	}

	args := []string{
		"--host", p.socketPath,
		"--model", p.cfg.Model,
		"--ctx-size", strconv.Itoa(p.cfg.ContextSize),
		"--alias", modelAlias,
		"--no-webui",
	}
	cmd := exec.Command(p.cfg.Binary, args...)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr

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

	slog.Info("llama-server iniciado", "pid", cmd.Process.Pid, "socket", p.socketPath, "model", p.cfg.Model)

	deadlineCtx, cancel := context.WithTimeout(ctx, startupTimeout)
	defer cancel()

	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()

	for {
		healthCtx, healthCancel := context.WithTimeout(deadlineCtx, 2*time.Second)
		err := p.client.Health(healthCtx)
		healthCancel()
		if err == nil {
			slog.Info("llama-server pronto", "socket", p.socketPath)
			return nil
		}

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
			_ = cmd.Process.Kill()
			<-waitCh
		}
	}

	if err := os.Remove(p.socketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}
