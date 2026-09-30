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
	ConfigDir      string
	StateDir       string
	RuntimeDir     string
	RoutesDir      string
	LlamaSocket    string
	GenerateSocket string
}

func DefaultPaths() Paths {
	runtimeDir:=DefaultRuntimeDir
	if override:=os.Getenv("AI_BASH_GEN_RUNTIME_DIR");override!=""{ runtimeDir=filepath.Clean(override) }
	routesDir:=filepath.Join(runtimeDir,"routes")
	return Paths{
		ConfigDir: DefaultConfigDir,
		StateDir: DefaultStateDir,
		RuntimeDir: runtimeDir,
		RoutesDir: routesDir,
		LlamaSocket: filepath.Join(runtimeDir,"internal","llama.sock"),
		GenerateSocket: filepath.Join(routesDir,"generate.sock"),
	}
}
