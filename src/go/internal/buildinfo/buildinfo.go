package buildinfo

import "fmt"

var (
	Version = "dev"
	Commit  = "unknown"
)

func String() string {
	return fmt.Sprintf("ai-bash-gen %s (commit %s)", Version, Commit)
}
