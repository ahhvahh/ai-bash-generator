package llama

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"path/filepath"
	"testing"
)

func TestClientUsesUnixSocketForHealthAndChat(t *testing.T) {
	socket := filepath.Join(t.TempDir(), "llama.sock")
	ln, err := net.Listen("unix", socket)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	srv := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/health":
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"status":"ok"}`))
		case "/v1/chat/completions":
			var req chatRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				t.Errorf("decode request: %v", err)
				http.Error(w, "bad request", http.StatusBadRequest)
				return
			}
			if req.Model != "ai-bash-gen" {
				t.Errorf("model=%q", req.Model)
			}
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte("{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"#!/usr/bin/env bash\\necho ok\"}}]}"))
		default:
			http.NotFound(w, r)
		}
	})}
	defer srv.Close()
	go srv.Serve(ln)

	client := NewClient(socket, "ai-bash-gen", 128, 0.1)
	if err := client.Health(context.Background()); err != nil {
		t.Fatal(err)
	}
	got, err := client.Complete(context.Background(), "system", "user")
	if err != nil {
		t.Fatal(err)
	}
	if got != "#!/usr/bin/env bash\necho ok" {
		t.Fatalf("content=%q", got)
	}
}
