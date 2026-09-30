package pipeline

import "context"

type StageName string

const (
	StageRequestNormalizer  StageName = "request-normalizer"
	StageSearchCapabilities StageName = "search-capabilities"
	StageBashGenerator      StageName = "bash-generator"
	StageValidation         StageName = "validation"
	StageBashOutput         StageName = "bash-output"
)

// Stage keeps orchestration independent from concrete Protobuf bindings.
// Concrete implementations should use generated messages at their boundaries.
type Stage[I any, O any] interface {
	Run(ctx context.Context, input I) (O, error)
}
