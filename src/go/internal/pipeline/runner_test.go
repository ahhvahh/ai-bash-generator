package pipeline

import (
	"context"
	"testing"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

type fakeCompleter struct {
	content string
	err     error
}

func (f fakeCompleter) Complete(context.Context, string, string) (string, error) {
	return f.content, f.err
}

func TestRunnerProducesValidatedArtifactAndAllStages(t *testing.T) {
	r := NewRunner(fakeCompleter{content: "```bash\necho \"Ola A-Bioma\"\n```"}, time.Second)
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

func TestRunnerRejectsInvalidBash(t *testing.T) {
	r := NewRunner(fakeCompleter{content: "if then"}, time.Second)
	_, err := r.Generate(context.Background(), protocol.GenerateRequest{Text: "teste"}, func(protocol.Stage, protocol.ProgressState, string) error {
		return nil
	})
	if err == nil {
		t.Fatal("esperava erro de sintaxe")
	}
}
