package main

import (
    "context"
    "crypto/sha256"
    "encoding/hex"
    "errors"
    "flag"
    "fmt"
    "net"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "time"

    "github.com/ahhvahh/ai-bash-generator/internal/output"
    "github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

const defaultSocket = "/run/ai-bash-gen/routes/generate.sock"

type testCase struct {
    Name string
    Prompt string
    Required []string
}

var cases = []testCase{
    {Name:"01-echo", Prompt:"Gere um script Bash que use echo para imprimir exatamente: Ola A-Bioma", Required:[]string{"echo", "Ola A-Bioma"}},
    {Name:"02-pwd", Prompt:"Gere um script Bash que mostre o diretório atual usando o comando pwd.", Required:[]string{"pwd"}},
    {Name:"03-ls", Prompt:"Gere um script Bash que liste arquivos, inclusive ocultos, usando ls -la.", Required:[]string{"ls", "-la"}},
    {Name:"04-df", Prompt:"Gere um script Bash que mostre o uso dos sistemas de arquivos usando df -h.", Required:[]string{"df", "-h"}},
    {Name:"05-find-sort-head", Prompt:"Gere um script Bash que encontre arquivos em /var/log, ordene por tamanho e mostre os 10 maiores usando find, sort e head.", Required:[]string{"find", "sort", "head", "/var/log"}},
    {Name:"06-tar-backup", Prompt:"Gere um script Bash que crie /tmp/etc-backup.tar.gz com o conteúdo de /etc usando tar.", Required:[]string{"tar", "/etc", "/tmp/etc-backup.tar.gz"}},
    {Name:"07-systemctl", Prompt:"Gere um script Bash que use systemctl is-active para verificar o serviço ssh e retorne erro se estiver inativo.", Required:[]string{"systemctl", "is-active", "ssh"}},
    {Name:"08-pipeline-texto", Prompt:"Gere um script Bash que leia /etc/passwd e conte shells usando awk, sort e uniq.", Required:[]string{"/etc/passwd", "awk", "sort", "uniq"}},
    {Name:"09-rsync-dry-run", Prompt:"Gere um script Bash que use rsync --dry-run para sincronizar /srv/dados/ para /backup/dados/ sem apagar arquivos.", Required:[]string{"rsync", "--dry-run", "/srv/dados", "/backup/dados"}},
    {Name:"10-backup-robusto", Prompt:"Gere um script Bash robusto com set -Eeuo pipefail, trap para limpeza, mktemp, tar de /etc e sha256sum do arquivo gerado. Não execute operações destrutivas.", Required:[]string{"set -Eeuo pipefail", "trap", "mktemp", "tar", "sha256sum", "/etc"}},
}

func main() {
    socket := flag.String("socket", defaultSocket, "Unix socket do serviço de geração")
    timeout := flag.Duration("timeout", 2*time.Minute, "timeout por caso")
    only := flag.String("case", "", "executa somente um caso pelo nome")
    flag.Parse()

    selected := cases
    if strings.TrimSpace(*only) != "" {
        selected = nil
        for _, tc := range cases {
            if tc.Name == *only { selected = append(selected, tc) }
        }
        if len(selected) == 0 {
            fmt.Fprintf(os.Stderr, "caso desconhecido: %s\n", *only)
            os.Exit(2)
        }
    }

    passed := 0
    for _, tc := range selected {
        fmt.Printf("[TEST] %s\n", tc.Name)
        ctx, cancel := context.WithTimeout(context.Background(), *timeout)
        result, stages, err := request(ctx, *socket, tc)
        cancel()
        if err != nil {
            fmt.Fprintf(os.Stderr, "[FAIL] %s: %v\n", tc.Name, err)
            os.Exit(1)
        }
        if result.ErrorCode == "PIPELINE_NOT_IMPLEMENTED" {
            fmt.Fprintf(os.Stderr, "[BLOCKED] pipeline real ainda não implementado: %s\n", result.ErrorMessage)
            os.Exit(3)
        }
        if result.ErrorCode != "" {
            fmt.Fprintf(os.Stderr, "[FAIL] %s: servidor [%s] %s\n", tc.Name, result.ErrorCode, result.ErrorMessage)
            os.Exit(1)
        }
        if err := validateArtifact(ctx, tc, result.Artifact, stages); err != nil {
            fmt.Fprintf(os.Stderr, "[FAIL] %s: %v\n", tc.Name, err)
            os.Exit(1)
        }
        passed++
        fmt.Printf("[PASS] %s server=%.3fs filename=%s\n", tc.Name, float64(result.ElapsedMS)/1000, result.Artifact.Filename)
    }
    fmt.Printf("RESULTADO: %d/%d casos aprovados\n", passed, len(selected))
}

func request(ctx context.Context, socket string, tc testCase) (protocol.GenerateResult, map[protocol.Stage]protocol.ProgressState, error) {
    var d net.Dialer
    conn, err := d.DialContext(ctx, "unix", socket)
    if err != nil { return protocol.GenerateResult{}, nil, fmt.Errorf("conectar em %s: %w", socket, err) }
    defer conn.Close()

    done := make(chan struct{})
    defer close(done)
    go func(){ select { case <-ctx.Done(): _ = conn.Close(); case <-done: } }()

    if err := protocol.WriteRequest(conn, protocol.GenerateRequest{Text:tc.Prompt, RequestedFilename:tc.Name+".sh"}); err != nil {
        return protocol.GenerateResult{}, nil, fmt.Errorf("enviar request: %w", err)
    }

    stages := map[protocol.Stage]protocol.ProgressState{}
    for {
        event, err := protocol.ReadEvent(conn)
        if err != nil { return protocol.GenerateResult{}, stages, fmt.Errorf("ler evento: %w", err) }
        if event.Progress != nil {
            stages[event.Progress.Stage] = event.Progress.State
            fmt.Printf("  [%7.3fs] %-20s %s %s\n", float64(event.Progress.ElapsedMS)/1000, event.Progress.Stage.String(), event.Progress.State.String(), event.Progress.Message)
            continue
        }
        if event.Result != nil { return *event.Result, stages, nil }
    }
}

func validateArtifact(ctx context.Context, tc testCase, artifact protocol.BashArtifact, stages map[protocol.Stage]protocol.ProgressState) error {
    if err := output.ValidateFilename(artifact.Filename); err != nil { return fmt.Errorf("filename inválido: %w", err) }
    if strings.TrimSpace(artifact.Content) == "" { return errors.New("conteúdo vazio") }

    if artifact.SHA256 != "" {
        sum := sha256.Sum256([]byte(artifact.Content))
        actual := hex.EncodeToString(sum[:])
        if !strings.EqualFold(actual, artifact.SHA256) { return fmt.Errorf("SHA-256 divergente: servidor=%s local=%s", artifact.SHA256, actual) }
    }

    lower := strings.ToLower(artifact.Content)
    for _, token := range tc.Required {
        if !strings.Contains(lower, strings.ToLower(token)) { return fmt.Errorf("conteúdo não contém requisito %q", token) }
    }

    expectedStages := []protocol.Stage{
        protocol.StageRequestNormalizer, protocol.StageSearchCapabilities, protocol.StageBashGenerator, protocol.StageValidation, protocol.StageBashOutput,
    }
    for _, stage := range expectedStages {
        if stages[stage] != protocol.StateCompleted { return fmt.Errorf("etapa %s não terminou com OK", stage.String()) }
    }

    tmp, err := os.CreateTemp("", "ai-bash-gen-smoke-*.sh")
    if err != nil { return err }
    name := tmp.Name()
    defer os.Remove(name)
    if _, err := tmp.WriteString(artifact.Content); err != nil { tmp.Close(); return err }
    if err := tmp.Close(); err != nil { return err }
    cmd := exec.CommandContext(ctx, "bash", "-n", filepath.Clean(name))
    if data, err := cmd.CombinedOutput(); err != nil { return fmt.Errorf("bash -n falhou: %w: %s", err, strings.TrimSpace(string(data))) }
    return nil
}
