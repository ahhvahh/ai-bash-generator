package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/observability"
	"github.com/ahhvahh/ai-bash-generator/internal/output"
	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

type Generator interface {
	Generate(ctx context.Context, request protocol.GenerateRequest, progress func(protocol.Stage, protocol.ProgressState, string) error) (protocol.BashArtifact, error)
}

type Server struct {
	SocketPath string
	Generator  Generator

	mu sync.Mutex
	ln net.Listener
	wg sync.WaitGroup
}

func New(socketPath string, generator Generator) *Server {
	return &Server{SocketPath: socketPath, Generator: generator}
}

func (s *Server) Start() error {
	if s.SocketPath == "" {
		return errors.New("socket de geração não definido")
	}
	if s.Generator == nil {
		return errors.New("pipeline de geração não configurado")
	}
	if err := os.MkdirAll(filepath.Dir(s.SocketPath), 0750); err != nil {
		return fmt.Errorf("criar diretório do socket: %w", err)
	}
	if info, err := os.Lstat(s.SocketPath); err == nil {
		if info.Mode()&os.ModeSocket == 0 {
			return fmt.Errorf("caminho do socket já existe e não é socket: %s", s.SocketPath)
		}
		if err := os.Remove(s.SocketPath); err != nil {
			return fmt.Errorf("remover socket antigo: %w", err)
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}

	ln, err := net.Listen("unix", s.SocketPath)
	if err != nil {
		return fmt.Errorf("listen unix %s: %w", s.SocketPath, err)
	}
	if err := os.Chmod(s.SocketPath, 0660); err != nil {
		ln.Close()
		return err
	}

	s.mu.Lock()
	s.ln = ln
	s.mu.Unlock()
	s.wg.Add(1)
	go s.acceptLoop(ln)
	return nil
}

func (s *Server) Close() error {
	s.mu.Lock()
	ln := s.ln
	s.ln = nil
	s.mu.Unlock()
	if ln != nil {
		_ = ln.Close()
	}
	s.wg.Wait()
	if err := os.Remove(s.SocketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

func (s *Server) acceptLoop(ln net.Listener) {
	defer s.wg.Done()
	for {
		conn, err := ln.Accept()
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return
			}
			slog.Error("falha ao aceitar cliente de geração", "error", err)
			continue
		}
		s.wg.Add(1)
		go func() {
			defer s.wg.Done()
			defer conn.Close()
			if err := s.handle(conn); err != nil && !errors.Is(err, io.EOF) {
				slog.Warn("requisição de geração encerrada com erro", "error", err)
			}
		}()
	}
}

func (s *Server) handle(conn net.Conn) error {
	started := time.Now()
	request, err := protocol.ReadRequest(conn)
	if err != nil {
		slog.Error("falha ao ler requisição", "event", "request_read_failed", "error", err)
		return fmt.Errorf("ler GenerateRequest: %w", err)
	}

	requestID := newRequestID()
	ctx := observability.WithRequestID(context.Background(), requestID)
	logger := observability.Logger(ctx).With("component", "generation-service")
	stageStarted := make(map[protocol.Stage]time.Time)

	logger.Info("requisição recebida",
		"event", "request_received",
		"instruction_chars", len([]rune(request.Text)),
		"instruction_bytes", len(request.Text),
		"requested_filename", request.RequestedFilename,
	)

	sendProgress := func(stage protocol.Stage, state protocol.ProgressState, message string) error {
		now := time.Now()
		elapsedMS := uint64(now.Sub(started).Milliseconds())
		stageName := stage.String()

		switch state {
		case protocol.StateStarted:
			stageStarted[stage] = now
			logger.Info("etapa iniciada",
				"event", "pipeline_stage_start",
				"stage", stageName,
				"elapsed_ms", elapsedMS,
				"message", message,
			)
		case protocol.StateCompleted:
			durationMS := int64(0)
			if stageStart, ok := stageStarted[stage]; ok {
				durationMS = now.Sub(stageStart).Milliseconds()
			}
			logger.Info("etapa concluída",
				"event", "pipeline_stage_complete",
				"stage", stageName,
				"elapsed_ms", elapsedMS,
				"duration_ms", durationMS,
				"message", message,
			)
		case protocol.StateFailed:
			durationMS := int64(0)
			if stageStart, ok := stageStarted[stage]; ok {
				durationMS = now.Sub(stageStart).Milliseconds()
			}
			logger.Error("etapa falhou",
				"event", "pipeline_stage_failed",
				"stage", stageName,
				"elapsed_ms", elapsedMS,
				"duration_ms", durationMS,
				"message", message,
			)
		default:
			logger.Debug("progresso de etapa",
				"event", "pipeline_stage_progress",
				"stage", stageName,
				"state", state.String(),
				"elapsed_ms", elapsedMS,
				"message", message,
			)
		}

		err := protocol.WriteEvent(conn, protocol.GenerateEvent{Progress: &protocol.ProgressEvent{
			RequestID: requestID,
			Stage: stage,
			State: state,
			ElapsedMS: elapsedMS,
			Message: message,
		}})
		if err != nil {
			logger.Error("falha ao enviar progresso ao cliente",
				"event", "progress_write_failed",
				"stage", stageName,
				"error", err,
			)
		}
		return err
	}

	sendResult := func(result protocol.GenerateResult) error {
		result.RequestID = requestID
		result.ElapsedMS = uint64(time.Since(started).Milliseconds())

		if result.ErrorCode != "" {
			logger.Error("requisição finalizada com erro",
				"event", "request_failed",
				"duration_ms", result.ElapsedMS,
				"error_code", result.ErrorCode,
				"error_message", result.ErrorMessage,
			)
		} else {
			logger.Info("requisição concluída",
				"event", "request_complete",
				"duration_ms", result.ElapsedMS,
				"filename", result.Artifact.Filename,
				"content_bytes", len(result.Artifact.Content),
				"sha256", result.Artifact.SHA256,
			)
		}

		if err := protocol.WriteEvent(conn, protocol.GenerateEvent{Result: &result}); err != nil {
			logger.Error("falha ao enviar resultado ao cliente", "event", "result_write_failed", "error", err)
			return err
		}
		return nil
	}
	sendError := func(code, message string) error {
		return sendResult(protocol.GenerateResult{ErrorCode: code, ErrorMessage: message})
	}

	if strings.TrimSpace(request.Text) == "" {
		logger.Warn("requisição rejeitada: instrução vazia", "event", "request_rejected")
		return sendError("INVALID_REQUEST", "a instrução não pode ser vazia")
	}
	if request.RequestedFilename != "" {
		if err := output.ValidateFilename(request.RequestedFilename); err != nil {
			logger.Warn("requisição rejeitada: filename inválido", "event", "request_rejected", "error", err)
			return sendError("INVALID_FILENAME", err.Error())
		}
	}

	artifact, err := s.Generator.Generate(ctx, request, sendProgress)
	if err != nil {
		return sendError("GENERATION_FAILED", err.Error())
	}
	return sendResult(protocol.GenerateResult{Artifact: artifact})
}

func newRequestID() string {
	var b [12]byte
	if _, err := rand.Read(b[:]); err == nil {
		return hex.EncodeToString(b[:])
	}
	return fmt.Sprintf("req-%d", time.Now().UnixNano())
}
