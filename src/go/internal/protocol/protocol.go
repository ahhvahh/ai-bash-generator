package protocol

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
)

const MaxFrameSize = 16 << 20

type Stage uint64

const (
	StageUnspecified Stage = iota
	StageRequestNormalizer
	StageSearchCapabilities
	StageBashGenerator
	StageValidation
	StageBashOutput
)

func (s Stage) String() string {
	switch s {
	case StageRequestNormalizer:
		return "request-normalizer"
	case StageSearchCapabilities:
		return "search-capabilities"
	case StageBashGenerator:
		return "bash-generator"
	case StageValidation:
		return "validation"
	case StageBashOutput:
		return "bash-output"
	default:
		return "unspecified"
	}
}

type ProgressState uint64

const (
	StateUnspecified ProgressState = iota
	StateStarted
	StateCompleted
	StateFailed
)

func (s ProgressState) String() string {
	switch s {
	case StateStarted:
		return "START"
	case StateCompleted:
		return "OK"
	case StateFailed:
		return "FAIL"
	default:
		return "?"
	}
}

type GenerateRequest struct {
	Text              string
	RequestedFilename string
}

type ProgressEvent struct {
	RequestID string
	Stage     Stage
	State     ProgressState
	ElapsedMS uint64
	Message   string
}

type BashArtifact struct {
	Filename       string
	Content        string
	SHA256         string
	FinalOutputRef string
}

type GenerateResult struct {
	RequestID    string
	Artifact     BashArtifact
	ElapsedMS    uint64
	ErrorCode    string
	ErrorMessage string
}

type GenerateEvent struct {
	Progress *ProgressEvent
	Result   *GenerateResult
}

func WriteRequest(w io.Writer, r GenerateRequest) error { return WriteFrame(w, MarshalRequest(r)) }
func ReadRequest(r io.Reader) (GenerateRequest, error) {
	b, err := ReadFrame(r)
	if err != nil { return GenerateRequest{}, err }
	return UnmarshalRequest(b)
}
func WriteEvent(w io.Writer, e GenerateEvent) error {
	b, err := MarshalEvent(e)
	if err != nil { return err }
	return WriteFrame(w, b)
}
func ReadEvent(r io.Reader) (GenerateEvent, error) {
	b, err := ReadFrame(r)
	if err != nil { return GenerateEvent{}, err }
	return UnmarshalEvent(b)
}

func WriteFrame(w io.Writer, payload []byte) error {
	if len(payload) > MaxFrameSize { return fmt.Errorf("frame excede limite: %d", len(payload)) }
	var h [4]byte
	binary.BigEndian.PutUint32(h[:], uint32(len(payload)))
	if _, err := w.Write(h[:]); err != nil { return err }
	_, err := w.Write(payload)
	return err
}

func ReadFrame(r io.Reader) ([]byte, error) {
	var h [4]byte
	if _, err := io.ReadFull(r, h[:]); err != nil { return nil, err }
	n := binary.BigEndian.Uint32(h[:])
	if n > MaxFrameSize { return nil, fmt.Errorf("frame excede limite: %d", n) }
	b := make([]byte, n)
	_, err := io.ReadFull(r, b)
	return b, err
}

func MarshalRequest(r GenerateRequest) []byte {
	var b []byte
	b = appendString(b, 1, r.Text)
	if r.RequestedFilename != "" { b = appendString(b, 2, r.RequestedFilename) }
	return b
}

func UnmarshalRequest(b []byte) (GenerateRequest, error) {
	var r GenerateRequest
	err := walk(b, func(f, w uint64, raw []byte, v uint64) error {
		if w != 2 { return errors.New("GenerateRequest: wire inválido") }
		switch f {
		case 1: r.Text = string(raw)
		case 2: r.RequestedFilename = string(raw)
		}
		return nil
	})
	return r, err
}

func MarshalEvent(e GenerateEvent) ([]byte, error) {
	if e.Progress != nil && e.Result == nil { return appendBytes(nil, 1, marshalProgress(*e.Progress)), nil }
	if e.Result != nil && e.Progress == nil { return appendBytes(nil, 2, marshalResult(*e.Result)), nil }
	return nil, errors.New("GenerateEvent deve conter exatamente um evento")
}

func UnmarshalEvent(b []byte) (GenerateEvent, error) {
	var e GenerateEvent
	err := walk(b, func(f, w uint64, raw []byte, v uint64) error {
		if w != 2 { return errors.New("GenerateEvent: wire inválido") }
		switch f {
		case 1:
			p, err := unmarshalProgress(raw); if err != nil { return err }; e.Progress = &p
		case 2:
			r, err := unmarshalResult(raw); if err != nil { return err }; e.Result = &r
		}
		return nil
	})
	if err != nil { return GenerateEvent{}, err }
	if (e.Progress == nil) == (e.Result == nil) { return GenerateEvent{}, errors.New("GenerateEvent inválido") }
	return e, nil
}

func marshalProgress(p ProgressEvent) []byte {
	var b []byte
	b = appendString(b, 1, p.RequestID)
	b = appendVarintField(b, 2, uint64(p.Stage))
	b = appendVarintField(b, 3, uint64(p.State))
	b = appendVarintField(b, 4, p.ElapsedMS)
	if p.Message != "" { b = appendString(b, 5, p.Message) }
	return b
}
func unmarshalProgress(b []byte) (ProgressEvent, error) {
	var p ProgressEvent
	err := walk(b, func(f, w uint64, raw []byte, v uint64) error {
		switch f {
		case 1: if w != 2 { return errors.New("progress request_id") }; p.RequestID = string(raw)
		case 2: if w != 0 { return errors.New("progress stage") }; p.Stage = Stage(v)
		case 3: if w != 0 { return errors.New("progress state") }; p.State = ProgressState(v)
		case 4: if w != 0 { return errors.New("progress elapsed") }; p.ElapsedMS = v
		case 5: if w != 2 { return errors.New("progress message") }; p.Message = string(raw)
		}
		return nil
	})
	return p, err
}

func marshalArtifact(a BashArtifact) []byte {
	var b []byte
	b = appendString(b, 1, a.Filename)
	b = appendString(b, 2, a.Content)
	if a.SHA256 != "" { b = appendString(b, 3, a.SHA256) }
	if a.FinalOutputRef != "" { b = appendString(b, 4, a.FinalOutputRef) }
	return b
}
func unmarshalArtifact(b []byte) (BashArtifact, error) {
	var a BashArtifact
	err := walk(b, func(f, w uint64, raw []byte, v uint64) error {
		if w != 2 { return errors.New("BashArtifact: wire inválido") }
		switch f { case 1: a.Filename=string(raw); case 2: a.Content=string(raw); case 3: a.SHA256=string(raw); case 4: a.FinalOutputRef=string(raw) }
		return nil
	})
	return a, err
}

func marshalResult(r GenerateResult) []byte {
	var b []byte
	b = appendString(b, 1, r.RequestID)
	if r.Artifact.Filename != "" || r.Artifact.Content != "" { b = appendBytes(b, 2, marshalArtifact(r.Artifact)) }
	b = appendVarintField(b, 3, r.ElapsedMS)
	if r.ErrorCode != "" { b = appendString(b, 4, r.ErrorCode) }
	if r.ErrorMessage != "" { b = appendString(b, 5, r.ErrorMessage) }
	return b
}
func unmarshalResult(b []byte) (GenerateResult, error) {
	var r GenerateResult
	err := walk(b, func(f, w uint64, raw []byte, v uint64) error {
		switch f {
		case 1: if w != 2 { return errors.New("result request_id") }; r.RequestID=string(raw)
		case 2: if w != 2 { return errors.New("result artifact") }; a,err:=unmarshalArtifact(raw); if err!=nil{return err}; r.Artifact=a
		case 3: if w != 0 { return errors.New("result elapsed") }; r.ElapsedMS=v
		case 4: if w != 2 { return errors.New("result error_code") }; r.ErrorCode=string(raw)
		case 5: if w != 2 { return errors.New("result error_message") }; r.ErrorMessage=string(raw)
		}
		return nil
	})
	return r, err
}

func appendString(b []byte, f uint64, s string) []byte { return appendBytes(b, f, []byte(s)) }
func appendBytes(b []byte, f uint64, v []byte) []byte {
	b=appendVarint(b,f<<3|2); b=appendVarint(b,uint64(len(v))); return append(b,v...)
}
func appendVarintField(b []byte, f,v uint64) []byte { b=appendVarint(b,f<<3); return appendVarint(b,v) }
func appendVarint(b []byte, v uint64) []byte {
	for v>=0x80 { b=append(b,byte(v)|0x80); v>>=7 }
	return append(b,byte(v))
}
func consumeVarint(b []byte)(uint64,int,error){
	var v uint64
	for i:=0;i<len(b)&&i<10;i++ { c:=b[i]; if i==9&&c>1{return 0,0,errors.New("varint overflow")}; v|=uint64(c&0x7f)<<(7*i); if c<0x80{return v,i+1,nil} }
	return 0,0,errors.New("varint inválido")
}
func walk(b []byte, fn func(uint64,uint64,[]byte,uint64)error) error {
	for len(b)>0 {
		key,n,err:=consumeVarint(b); if err!=nil{return err}; b=b[n:]; f,w:=key>>3,key&7; if f==0{return errors.New("campo zero")}
		switch w {
		case 0:
			v,n,err:=consumeVarint(b); if err!=nil{return err}; b=b[n:]; if err=fn(f,w,nil,v);err!=nil{return err}
		case 2:
			l,n,err:=consumeVarint(b);if err!=nil{return err};b=b[n:];if l>uint64(len(b)){return io.ErrUnexpectedEOF};raw:=b[:int(l)];b=b[int(l):];if err=fn(f,w,raw,0);err!=nil{return err}
		case 1: if len(b)<8{return io.ErrUnexpectedEOF};b=b[8:]
		case 5: if len(b)<4{return io.ErrUnexpectedEOF};b=b[4:]
		default:return fmt.Errorf("wire não suportado: %d",w)
		}
	}
	return nil
}
