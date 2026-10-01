package pipeline

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

type fakeCompleter struct {
	content string
	err     error
	calls   int
	prompts []string
}

func (f *fakeCompleter) Complete(_ context.Context, _ string, userPrompt string) (string, error) {
	f.calls++
	f.prompts = append(f.prompts, userPrompt)
	return f.content, f.err
}

type sequenceCompleter struct {
	contents []string
	calls    int
	prompts  []string
}

func (f *sequenceCompleter) Complete(_ context.Context, _ string, userPrompt string) (string, error) {
	f.prompts = append(f.prompts, userPrompt)
	if f.calls >= len(f.contents) {
		f.calls++
		return "", nil
	}
	content := f.contents[f.calls]
	f.calls++
	return content, nil
}

func TestRunnerProducesValidatedArtifactAndAllStages(t *testing.T) {
	completer := &fakeCompleter{content: "```bash\necho \"Ola A-Bioma\"\n```"}
	r := NewRunner(completer, time.Second)
	states := map[protocol.Stage]protocol.ProgressState{}

	artifact, err := r.Generate(context.Background(), protocol.GenerateRequest{
		Text:              "mostre Ola A-Bioma",
		RequestedFilename: "hello.sh",
	}, func(stage protocol.Stage, state protocol.ProgressState, _ string) error {
		states[stage] = state
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if artifact.Filename != "hello.sh" || artifact.SHA256 == "" {
		t.Fatalf("artefato inesperado: %#v", artifact)
	}
	if artifact.Content != "#!/usr/bin/env bash\necho \"Ola A-Bioma\"\n" {
		t.Fatalf("content=%q", artifact.Content)
	}
	if completer.calls != 1 {
		t.Fatalf("calls=%d want=1", completer.calls)
	}

	for _, stage := range []protocol.Stage{
		protocol.StageRequestNormalizer,
		protocol.StageSearchCapabilities,
		protocol.StageBashGenerator,
		protocol.StageValidation,
		protocol.StageBashOutput,
	} {
		if states[stage] != protocol.StateCompleted {
			t.Fatalf("stage %s=%s", stage.String(), states[stage].String())
		}
	}
}

func TestRunnerRetriesInvalidBashWithValidationFeedback(t *testing.T) {
	completer := &sequenceCompleter{contents: []string{
		"#!/usr/bin/env bash\necho \"nao fechado\n",
		"#!/usr/bin/env bash\nset -Eeuo pipefail\ndf -h\n",
	}}
	r := NewRunner(completer, time.Second)
	var validationFailed bool

	artifact, err := r.Generate(context.Background(), protocol.GenerateRequest{
		Text:              "mostre o uso dos discos com df -h",
		RequestedFilename: "disco.sh",
	}, func(stage protocol.Stage, state protocol.ProgressState, _ string) error {
		if stage == protocol.StageValidation && state == protocol.StateFailed {
			validationFailed = true
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if completer.calls != 2 {
		t.Fatalf("calls=%d want=2", completer.calls)
	}
	if !validationFailed {
		t.Fatal("esperava registrar falha recuperável da primeira validação")
	}
	if len(completer.prompts) != 2 {
		t.Fatalf("prompts=%d", len(completer.prompts))
	}
	if !strings.Contains(completer.prompts[1], "Original request:") ||
		!strings.Contains(completer.prompts[1], "df -h") ||
		!strings.Contains(completer.prompts[1], "bash -n validation error:") {
		t.Fatalf("prompt de reparo não contém contexto suficiente: %q", completer.prompts[1])
	}
	if artifact.Content != "#!/usr/bin/env bash\nset -Eeuo pipefail\ndf -h\n" {
		t.Fatalf("content=%q", artifact.Content)
	}
}

func TestRunnerRejectsInvalidBashAfterRetry(t *testing.T) {
	completer := &fakeCompleter{content: "if then"}
	r := NewRunner(completer, time.Second)
	_, err := r.Generate(context.Background(), protocol.GenerateRequest{Text: "teste"}, func(protocol.Stage, protocol.ProgressState, string) error {
		return nil
	})
	if err == nil {
		t.Fatal("esperava erro de sintaxe")
	}
	if completer.calls != maxGenerationAttempts {
		t.Fatalf("calls=%d want=%d", completer.calls, maxGenerationAttempts)
	}
	if !strings.Contains(err.Error(), "após 2 tentativas") {
		t.Fatalf("erro inesperado: %v", err)
	}
}

func TestBuildRepairPromptTruncatesLongValidationError(t *testing.T) {
	longErr := strings.Repeat("x", 5000)
	prompt := buildRepairPrompt("teste", &testError{message: longErr})
	if len([]rune(prompt)) > 1600 {
		t.Fatalf("prompt de reparo excessivamente grande: %d runes", len([]rune(prompt)))
	}
	if !strings.Contains(prompt, "Generate the script again FROM SCRATCH") {
		t.Fatalf("prompt inesperado: %q", prompt)
	}
}

type testError struct{ message string }

func (e *testError) Error() string { return e.message }
