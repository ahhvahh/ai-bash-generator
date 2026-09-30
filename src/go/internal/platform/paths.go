package platform

import "path/filepath"

const (
	DefaultConfigDir  = "/etc/ai-bash-gen"
	DefaultStateDir   = "/var/lib/ai-bash-gen"
	DefaultRuntimeDir = "/run/ai-bash-gen"
)

type Paths struct {
	ConfigDir   string
	StateDir    string
	RuntimeDir  string
	RoutesDir   string
	LlamaSocket string
}

func DefaultPaths() Paths {
	return Paths{
		ConfigDir:   DefaultConfigDir,
		StateDir:    DefaultStateDir,
		RuntimeDir:  DefaultRuntimeDir,
		RoutesDir:   filepath.Join(DefaultRuntimeDir, "routes"),
		LlamaSocket: filepath.Join(DefaultRuntimeDir, "internal", "llama.sock"),
	}
}
