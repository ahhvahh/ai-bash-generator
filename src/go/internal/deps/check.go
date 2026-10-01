package deps

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/config"
)

const probeTimeout = 8 * time.Second

func Validate(cfg config.Config) error {
	var problems []string

	bash, err := exec.LookPath("bash")
	if err != nil {
		problems = append(problems, "bash não encontrado no PATH")
	} else if err := probeExecutable(bash, "--version"); err != nil {
		problems = append(problems, fmt.Sprintf("bash indisponível: %v", err))
	}

	checkedBinaries := map[string]bool{}
	for label, agent := range map[string]config.LlamaConfig{
		"request-normalizer": cfg.NormalizerConfig(),
		"bash-generator":     cfg.GeneratorConfig(),
	} {
		if !checkedBinaries[agent.Binary] {
			if err := validateExecutable(agent.Binary); err != nil {
				problems = append(problems, fmt.Sprintf("%s llama-server inválido: %v", label, err))
			} else if err := validateLlamaServer(agent.Binary); err != nil {
				problems = append(problems, fmt.Sprintf("%s: %v", label, err))
			}
			checkedBinaries[agent.Binary] = true
		}
		if err := validateModel(agent.Model); err != nil {
			problems = append(problems, fmt.Sprintf("%s modelo GGUF inválido: %v", label, err))
		}
	}

	if cfg.Database.Required {
		psql, err := exec.LookPath("psql")
		if err != nil {
			problems = append(problems, "psql não encontrado no PATH; PostgreSQL client é obrigatório")
		} else if err := probeExecutable(psql, "--version"); err != nil {
			problems = append(problems, fmt.Sprintf("psql indisponível: %v", err))
		}
	}

	if len(problems) != 0 {
		return fmt.Errorf("dependências de runtime indisponíveis: %s", strings.Join(problems, "; "))
	}
	return nil
}

func validateExecutable(path string) error {
	if !filepath.IsAbs(path) {
		return errors.New("caminho deve ser absoluto")
	}
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return errors.New("não é arquivo regular")
	}
	if info.Mode().Perm()&0111 == 0 {
		return errors.New("arquivo não possui permissão de execução")
	}
	return nil
}

func validateModel(path string) error {
	if !filepath.IsAbs(path) {
		return errors.New("caminho deve ser absoluto")
	}
	if !strings.EqualFold(filepath.Ext(path), ".gguf") {
		return errors.New("arquivo deve possuir extensão .gguf")
	}
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return errors.New("não é arquivo regular")
	}
	if info.Size() == 0 {
		return errors.New("arquivo está vazio")
	}
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("arquivo não pode ser lido: %w", err)
	}
	defer f.Close()

	var magic [4]byte
	if _, err := io.ReadFull(f, magic[:]); err != nil {
		return fmt.Errorf("arquivo GGUF truncado: %w", err)
	}
	if string(magic[:]) != "GGUF" {
		return fmt.Errorf("assinatura GGUF inválida: %q", string(magic[:]))
	}
	return nil
}

func validateLlamaServer(path string) error {
	ctx, cancel := context.WithTimeout(context.Background(), probeTimeout)
	defer cancel()

	out, err := exec.CommandContext(ctx, path, "--help").CombinedOutput()
	if ctx.Err() != nil {
		return fmt.Errorf("llama-server não respondeu a --help em %s", probeTimeout)
	}
	if err != nil {
		return fmt.Errorf("llama-server falhou ao executar --help: %w", err)
	}

	help := string(out)
	if !strings.Contains(help, "--host") {
		return errors.New("llama-server incompatível: opção --host não encontrada")
	}
	lower := strings.ToLower(help)
	if !strings.Contains(lower, "unix") && !strings.Contains(lower, ".sock") {
		return errors.New("llama-server incompatível: suporte a Unix socket não identificado")
	}
	return nil
}

func probeExecutable(path string, arg string) error {
	ctx, cancel := context.WithTimeout(context.Background(), probeTimeout)
	defer cancel()
	if err := exec.CommandContext(ctx, path, arg).Run(); err != nil {
		return err
	}
	return nil
}
