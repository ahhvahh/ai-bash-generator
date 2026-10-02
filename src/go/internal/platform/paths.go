package platform

import (
	"os"
	"path/filepath"
)

const (
	DefaultConfigDir  = "/etc/ai-bash-gen"
	DefaultStateDir   = "/var/lib/ai-bash-gen"
	DefaultRuntimeDir = "/run/ai-bash-gen"
)

type Paths struct {
	ConfigDir        string
	StateDir         string
	RuntimeDir       string
	RoutesDir        string
	LlamaSocket      string // legacy alias for GeneratorSocket
	NormalizerSocket string
	GeneratorSocket  string
	GenerateSocket   string
}

func DefaultPaths() Paths {
	runtimeDir := DefaultRuntimeDir
	if override := os.Getenv("AI_BASH_GEN_RUNTIME_DIR"); override != "" {
		runtimeDir = filepath.Clean(override)
	}
	routesDir := filepath.Join(runtimeDir, "routes")
	generatorSocket := filepath.Join(runtimeDir, "internal", "bash-generator.sock")
	return Paths{
		ConfigDir:        DefaultConfigDir,
		StateDir:         DefaultStateDir,
		RuntimeDir:       runtimeDir,
		RoutesDir:        routesDir,
		LlamaSocket:      generatorSocket,
		NormalizerSocket: filepath.Join(runtimeDir, "internal", "request-normalizer.sock"),
		GeneratorSocket:  generatorSocket,
		GenerateSocket:   filepath.Join(routesDir, "generate.sock"),
	}
}
