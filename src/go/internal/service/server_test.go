package service

import (
	"context"
	"net"
	"path/filepath"
	"testing"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

type fakeGenerator struct{}

func (fakeGenerator) Generate(_ context.Context, req protocol.GenerateRequest, progress func(protocol.Stage, protocol.ProgressState, string) error) (protocol.BashArtifact, error) {
	for _, stage := range []protocol.Stage{
		protocol.StageRequestNormalizer,
		protocol.StageSearchCapabilities,
		protocol.StageBashGenerator,
		protocol.StageValidation,
		protocol.StageBashOutput,
	} {
		if err := progress(stage, protocol.StateStarted, "start"); err != nil {
			return protocol.BashArtifact{}, err
		}
		if err := progress(stage, protocol.StateCompleted, "ok"); err != nil {
			return protocol.BashArtifact{}, err
		}
	}
	return protocol.BashArtifact{Filename: req.RequestedFilename, Content: "#!/usr/bin/env bash\necho ok\n", SHA256: "abc"}, nil
}

func TestServerStreamsPipelineAndReturnsArtifact(t *testing.T) {
	socket := filepath.Join(t.TempDir(), "generate.sock")
	s := New(socket, fakeGenerator{})
	if err := s.Start(); err != nil {
		t.Fatal(err)
	}
	defer s.Close()

	conn, err := net.DialTimeout("unix", socket, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if err := protocol.WriteRequest(conn, protocol.GenerateRequest{Text: "gere um script", RequestedFilename: "test.sh"}); err != nil {
		t.Fatal(err)
	}

	completed := map[protocol.Stage]bool{}
	for {
		event, err := protocol.ReadEvent(conn)
		if err != nil {
			t.Fatal(err)
		}
		if event.Progress != nil {
			if event.Progress.State == protocol.StateCompleted {
				completed[event.Progress.Stage] = true
			}
			continue
		}
		if event.Result == nil {
			t.Fatalf("evento inesperado=%#v", event)
		}
		if event.Result.ErrorCode != "" {
			t.Fatalf("erro servidor=%s: %s", event.Result.ErrorCode, event.Result.ErrorMessage)
		}
		if event.Result.Artifact.Filename != "test.sh" {
			t.Fatalf("artefato=%#v", event.Result.Artifact)
		}
		break
	}

	for _, stage := range []protocol.Stage{
		protocol.StageRequestNormalizer,
		protocol.StageSearchCapabilities,
		protocol.StageBashGenerator,
		protocol.StageValidation,
		protocol.StageBashOutput,
	} {
		if !completed[stage] {
			t.Fatalf("etapa %s não completou", stage.String())
		}
	}
}
