package service

import (
	"net"
	"path/filepath"
	"testing"
	"time"

	"github.com/ahhvahh/ai-bash-generator/internal/protocol"
)

func TestServerStreamsProgressAndExplicitUnavailableResult(t *testing.T) {
	socket:=filepath.Join(t.TempDir(),"generate.sock")
	s:=New(socket)
	if err:=s.Start();err!=nil{t.Fatal(err)}
	defer s.Close()

	conn,err:=net.DialTimeout("unix",socket,time.Second);if err!=nil{t.Fatal(err)}
	defer conn.Close()
	if err:=protocol.WriteRequest(conn,protocol.GenerateRequest{Text:"gere um script"});err!=nil{t.Fatal(err)}

	first,err:=protocol.ReadEvent(conn);if err!=nil{t.Fatal(err)}
	if first.Progress==nil||first.Progress.Stage!=protocol.StageRequestNormalizer||first.Progress.State!=protocol.StateStarted{t.Fatalf("primeiro evento=%#v",first)}

	second,err:=protocol.ReadEvent(conn);if err!=nil{t.Fatal(err)}
	if second.Progress==nil||second.Progress.State!=protocol.StateFailed{t.Fatalf("segundo evento=%#v",second)}

	final,err:=protocol.ReadEvent(conn);if err!=nil{t.Fatal(err)}
	if final.Result==nil||final.Result.ErrorCode!="PIPELINE_NOT_IMPLEMENTED"{t.Fatalf("resultado=%#v",final)}
}
