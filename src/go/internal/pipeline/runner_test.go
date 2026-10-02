package pipeline

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

const normalizedFixture = `intent: "disk_usage"
canonical_instruction: "Show filesystem disk usage."
input_description: "Local system."
output_description: "Human-readable disk usage."
tasks {
  id: "collect_disk_usage"
  instruction: "Collect filesystem disk usage."
  output {
    name: "diskUsage"
    contract {
      kind: DATA_KIND_TEXT
      encoding: STREAM_ENCODING_TEXT_UTF8
    }
  }
}
final_output_ref: "diskUsage"
status: NORMALIZATION_STATUS_READY`

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

type fakeSearcher struct {
	result string
	calls  int
}

func (f *fakeSearcher) Search(_ context.Context, normalized string) (string, error) {
	f.calls++
	if !strings.Contains(normalized, "canonical_instruction") {
		return "", &testError{"normalized request ausente"}
	}
	return f.result, nil
}

func TestRunnerUsesNormalizerCatalogAndGenerator(t *testing.T) {
	normalizer := &fakeCompleter{content: normalizedFixture}
	generator := &fakeCompleter{content: "#!/usr/bin/env bash\nset -Eeuo pipefail\ndf -h\n"}
	searcher := &fakeSearcher{result: "query[0]: Show filesystem disk usage.\n  candidates: 0\n"}
	r := NewRunner(normalizer, generator, searcher, time.Second)

	result, err := r.Generate(context.Background(), protocol.GenerateRequest{
		Text:              "mostre o uso dos discos",
		RequestedFilename: "disco.sh",
	}, func(protocol.Stage, protocol.ProgressState, string) error { return nil })
	if err != nil {
		t.Fatal(err)
	}
	if normalizer.calls != 1 || searcher.calls != 1 || generator.calls != 1 {
		t.Fatalf("calls normalizer=%d searcher=%d generator=%d", normalizer.calls, searcher.calls, generator.calls)
	}
	if result.Artifact.Filename != "disco.sh" {
		t.Fatalf("artifact=%#v", result.Artifact)
	}
	if !strings.Contains(result.Artifact.Content, "df -h") {
		t.Fatalf("content=%q", result.Artifact.Content)
	}
	if !strings.Contains(generator.prompts[0], "NormalizedRequest:") ||
		!strings.Contains(generator.prompts[0], "Capability candidates retrieved from PostgreSQL:") {
		t.Fatalf("generator prompt não contém handoff esperado: %q", generator.prompts[0])
	}
}

func TestRunnerCanStopAfterNormalizer(t *testing.T) {
	normalizer := &fakeCompleter{content: normalizedFixture}
	generator := &fakeCompleter{content: "echo should-not-run"}
	searcher := &fakeSearcher{result: "should-not-run"}
	r := NewRunner(normalizer, generator, searcher, time.Second)

	result, err := r.Generate(context.Background(), protocol.GenerateRequest{
		Text:           "mostre o uso dos discos",
		StopAfterStage: protocol.StageRequestNormalizer,
	}, func(protocol.Stage, protocol.ProgressState, string) error { return nil })
	if err != nil {
		t.Fatal(err)
	}
	if result.StageOutput == nil || result.StageOutput.Stage != protocol.StageRequestNormalizer {
		t.Fatalf("stage output=%#v", result.StageOutput)
	}
	if searcher.calls != 0 || generator.calls != 0 {
		t.Fatalf("etapas posteriores foram executadas")
	}
	if !strings.Contains(result.StageOutput.Content, "NORMALIZATION_STATUS_READY") {
		t.Fatalf("normalized output=%q", result.StageOutput.Content)
	}
}

func TestRunnerCanStopAfterCatalogSearch(t *testing.T) {
	normalizer := &fakeCompleter{content: normalizedFixture}
	generator := &fakeCompleter{content: "echo should-not-run"}
	searcher := &fakeSearcher{result: "query[0]: test\n  candidates: 1\n  - id: disk-usage\n"}
	r := NewRunner(normalizer, generator, searcher, time.Second)

	result, err := r.Generate(context.Background(), protocol.GenerateRequest{
		Text:           "mostre o uso dos discos",
		StopAfterStage: protocol.StageSearchCapabilities,
	}, func(protocol.Stage, protocol.ProgressState, string) error { return nil })
	if err != nil {
		t.Fatal(err)
	}
	if result.StageOutput == nil || !strings.Contains(result.StageOutput.Content, "disk-usage") {
		t.Fatalf("stage output=%#v", result.StageOutput)
	}
	if generator.calls != 0 {
		t.Fatalf("generator executado indevidamente")
	}
}

func TestRunnerRetriesInvalidBashWithValidationFeedback(t *testing.T) {
	normalizer := &fakeCompleter{content: normalizedFixture}
	generator := &sequenceCompleter{contents: []string{
		"#!/usr/bin/env bash\necho \"nao fechado\n",
		"#!/usr/bin/env bash\nset -Eeuo pipefail\ndf -h\n",
	}}
	searcher := &fakeSearcher{result: "candidates: 0\n"}
	r := NewRunner(normalizer, generator, searcher, time.Second)

	result, err := r.Generate(context.Background(), protocol.GenerateRequest{Text: "mostre discos"}, func(protocol.Stage, protocol.ProgressState, string) error {
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if generator.calls != 2 {
		t.Fatalf("generator calls=%d want=2", generator.calls)
	}
	if !strings.Contains(generator.prompts[1], "bash -n validation error:") {
		t.Fatalf("repair prompt=%q", generator.prompts[1])
	}
	if !strings.Contains(result.Artifact.Content, "df -h") {
		t.Fatalf("content=%q", result.Artifact.Content)
	}
}

func TestRunnerRejectsInvalidNormalizedRequest(t *testing.T) {
	normalizer := &fakeCompleter{content: "status: NORMALIZATION_STATUS_READY"}
	generator := &fakeCompleter{content: "echo ok"}
	searcher := &fakeSearcher{}
	r := NewRunner(normalizer, generator, searcher, time.Second)

	_, err := r.Generate(context.Background(), protocol.GenerateRequest{Text: "teste"}, func(protocol.Stage, protocol.ProgressState, string) error {
		return nil
	})
	if err == nil || !strings.Contains(err.Error(), "canonical_instruction") {
		t.Fatalf("erro inesperado: %v", err)
	}
}

type testError struct{ message string }
func (e *testError) Error() string { return e.message }
