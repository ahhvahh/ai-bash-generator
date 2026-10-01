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
		return fmt.Errorf("ler GenerateRequest: %w", err)
	}
	requestID := newRequestID()

	sendProgress := func(stage protocol.Stage, state protocol.ProgressState, message string) error {
		return protocol.WriteEvent(conn, protocol.GenerateEvent{Progress: &protocol.ProgressEvent{
			RequestID: requestID,
			Stage: stage,
			State: state,
			ElapsedMS: uint64(time.Since(started).Milliseconds()),
			Message: message,
		}})
	}
	sendResult := func(result protocol.GenerateResult) error {
		result.RequestID = requestID
		result.ElapsedMS = uint64(time.Since(started).Milliseconds())
		return protocol.WriteEvent(conn, protocol.GenerateEvent{Result: &result})
	}
	sendError := func(code, message string) error {
		return sendResult(protocol.GenerateResult{ErrorCode: code, ErrorMessage: message})
	}

	if strings.TrimSpace(request.Text) == "" {
		return sendError("INVALID_REQUEST", "a instrução não pode ser vazia")
	}
	if request.RequestedFilename != "" {
		if err := output.ValidateFilename(request.RequestedFilename); err != nil {
			return sendError("INVALID_FILENAME", err.Error())
		}
	}

	artifact, err := s.Generator.Generate(context.Background(), request, sendProgress)
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
