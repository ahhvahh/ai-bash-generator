package llama

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/observability"
)

type Client struct {
	socket      string
	model       string
	maxTokens   int
	temperature float64
	http        *http.Client
}

func NewClient(socket, model string, maxTokens int, temperature float64) *Client {
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", socket)
		},
	}
	return &Client{
		socket: socket,
		model: model,
		maxTokens: maxTokens,
		temperature: temperature,
		http: &http.Client{Transport: transport},
	}
}

func (c *Client) Health(ctx context.Context) error {
	started := time.Now()
	logger := observability.Logger(ctx).With("component", "llama-client", "endpoint", "/health")
	logger.Debug("verificando saúde do llama-server", "event", "llama_health_start", "socket", c.socket)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://unix/health", nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		logger.Debug("llama-server ainda não respondeu ao health",
			"event", "llama_health_failed",
			"duration_ms", time.Since(started).Milliseconds(),
			"error", err,
		)
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 8192))
		err := fmt.Errorf("llama-server health HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
		logger.Warn("health do llama-server retornou status inesperado",
			"event", "llama_health_failed",
			"http_status", resp.StatusCode,
			"duration_ms", time.Since(started).Milliseconds(),
			"error", err,
		)
		return err
	}
	logger.Debug("llama-server saudável",
		"event", "llama_health_ok",
		"http_status", resp.StatusCode,
		"duration_ms", time.Since(started).Milliseconds(),
	)
	return nil
}

func (c *Client) Complete(ctx context.Context, systemPrompt, userPrompt string) (string, error) {
	started := time.Now()
	logger := observability.Logger(ctx).With(
		"component", "llama-client",
		"endpoint", "/v1/chat/completions",
		"model", c.model,
	)

	payload := chatRequest{
		Model: c.model,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userPrompt},
		},
		MaxTokens: c.maxTokens,
		Temperature: c.temperature,
		Stream: false,
	}
	data, err := json.Marshal(payload)
	if err != nil {
		logger.Error("falha ao serializar requisição para llama-server", "event", "llama_request_encode_failed", "error", err)
		return "", err
	}

	logger.Debug("chamada ao llama-server iniciada",
		"event", "llama_request_start",
		"socket", c.socket,
		"request_bytes", len(data),
		"system_prompt_chars", len([]rune(systemPrompt)),
		"user_prompt_chars", len([]rune(userPrompt)),
		"max_tokens", c.maxTokens,
		"temperature", c.temperature,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://unix/v1/chat/completions", bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		logger.Error("falha na chamada ao llama-server",
			"event", "llama_request_failed",
			"duration_ms", time.Since(started).Milliseconds(),
			"error", err,
		)
		return "", fmt.Errorf("chamar llama-server: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		logger.Error("falha ao ler resposta do llama-server",
			"event", "llama_response_read_failed",
			"http_status", resp.StatusCode,
			"duration_ms", time.Since(started).Milliseconds(),
			"error", err,
		)
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("llama-server HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
		logger.Error("llama-server retornou erro",
			"event", "llama_request_failed",
			"http_status", resp.StatusCode,
			"response_bytes", len(body),
			"duration_ms", time.Since(started).Milliseconds(),
			"error", err,
		)
		return "", err
	}

	var decoded chatResponse
	if err := json.Unmarshal(body, &decoded); err != nil {
		logger.Error("falha ao decodificar resposta do llama-server",
			"event", "llama_response_decode_failed",
			"http_status", resp.StatusCode,
			"response_bytes", len(body),
			"duration_ms", time.Since(started).Milliseconds(),
			"error", err,
		)
		return "", fmt.Errorf("decodificar resposta do llama-server: %w", err)
	}
	if len(decoded.Choices) == 0 {
		err := fmt.Errorf("llama-server retornou resposta sem choices")
		logger.Error("resposta do llama-server sem choices", "event", "llama_response_invalid", "error", err)
		return "", err
	}

	content := strings.TrimSpace(decoded.Choices[0].Message.Content)
	if content == "" {
		err := fmt.Errorf("llama-server retornou conteúdo vazio")
		logger.Error("resposta vazia do llama-server", "event", "llama_response_invalid", "error", err)
		return "", err
	}

	logger.Info("chamada ao llama-server concluída",
		"event", "llama_request_complete",
		"http_status", resp.StatusCode,
		"duration_ms", time.Since(started).Milliseconds(),
		"response_bytes", len(body),
		"content_chars", len([]rune(content)),
		"prompt_tokens", decoded.Usage.PromptTokens,
		"completion_tokens", decoded.Usage.CompletionTokens,
		"total_tokens", decoded.Usage.TotalTokens,
	)
	return content, nil
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatRequest struct {
	Model       string        `json:"model"`
	Messages    []chatMessage `json:"messages"`
	MaxTokens   int           `json:"max_tokens,omitempty"`
	Temperature float64       `json:"temperature,omitempty"`
	Stream      bool          `json:"stream"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
	Usage struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"usage"`
}
