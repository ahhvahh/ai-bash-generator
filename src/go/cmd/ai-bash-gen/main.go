package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/ahhvahh/ai-bash-generator/internal/buildinfo"
	"github.com/ahhvahh/ai-bash-generator/internal/platform"
)

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	fs := flag.NewFlagSet("ai-bash-gen", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	showVersion := fs.Bool("version", false, "exibe a versão")
	showPaths := fs.Bool("show-paths", false, "exibe os caminhos padrão do serviço")

	fs.Usage = func() {
		fmt.Fprintln(fs.Output(), "Uso: ai-bash-gen [--version] [--show-paths]")
		fmt.Fprintln(fs.Output(), "")
		fmt.Fprintln(fs.Output(), "O daemon completo será habilitado após a definição do contrato externo api.proto.")
		fs.PrintDefaults()
	}

	if err := fs.Parse(args); err != nil {
		return 2
	}

	switch {
	case *showVersion:
		fmt.Println(buildinfo.String())
		return 0
	case *showPaths:
		paths := platform.DefaultPaths()
		fmt.Printf("config_dir=%s\n", paths.ConfigDir)
		fmt.Printf("state_dir=%s\n", paths.StateDir)
		fmt.Printf("runtime_dir=%s\n", paths.RuntimeDir)
		fmt.Printf("routes_dir=%s\n", paths.RoutesDir)
		fmt.Printf("llama_socket=%s\n", paths.LlamaSocket)
		return 0
	default:
		fs.Usage()
		return 0
	}
}
