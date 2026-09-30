package main

import (
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/ahhvahh/ai-bash-generator/internal/buildinfo"
	"github.com/ahhvahh/ai-bash-generator/internal/platform"
	"github.com/ahhvahh/ai-bash-generator/internal/service"
)

func main(){ os.Exit(run(os.Args[1:])) }

func run(args []string) int {
	fs:=flag.NewFlagSet("ai-bash-gen",flag.ContinueOnError);fs.SetOutput(os.Stderr)
	showVersion:=fs.Bool("version",false,"exibe a versão")
	showPaths:=fs.Bool("show-paths",false,"exibe os caminhos padrão do serviço")
	configPath:=fs.String("config","","inicia o serviço usando o arquivo de configuração informado")
	fs.Usage=func(){
		fmt.Fprintln(fs.Output(),"Uso: ai-bash-gen [--version] [--show-paths] [--config <arquivo>]")
		fmt.Fprintln(fs.Output(),"")
		fmt.Fprintln(fs.Output(),"Modo serviço:")
		fmt.Fprintln(fs.Output(),"  ai-bash-gen --config /etc/ai-bash-gen/config.yaml")
		fmt.Fprintln(fs.Output(),"")
		fs.PrintDefaults()
	}
	if err:=fs.Parse(args);err!=nil{if errors.Is(err,flag.ErrHelp){return 0};return 2}
	if fs.NArg()!=0{fmt.Fprintf(fs.Output(),"argumento inesperado: %s\n",fs.Arg(0));fs.Usage();return 2}

	switch {
	case *showVersion:
		fmt.Println(buildinfo.String());return 0
	case *showPaths:
		p:=platform.DefaultPaths()
		fmt.Printf("config_dir=%s\n",p.ConfigDir)
		fmt.Printf("state_dir=%s\n",p.StateDir)
		fmt.Printf("runtime_dir=%s\n",p.RuntimeDir)
		fmt.Printf("routes_dir=%s\n",p.RoutesDir)
		fmt.Printf("llama_socket=%s\n",p.LlamaSocket)
		fmt.Printf("generate_socket=%s\n",p.GenerateSocket)
		return 0
	case *configPath!="":
		return runDaemon(*configPath)
	default:
		fs.Usage();return 0
	}
}

func runDaemon(configPath string) int {
	configData,err:=os.ReadFile(configPath)
	if err!=nil{slog.Error("falha ao carregar configuração","config",configPath,"error",err);return 1}

	paths:=platform.DefaultPaths()
	generationService:=service.New(paths.GenerateSocket)
	if err:=generationService.Start();err!=nil{
		slog.Error("falha ao iniciar serviço de geração","socket",paths.GenerateSocket,"error",err)
		return 1
	}
	defer generationService.Close()

	slog.Info("ai-bash-gen iniciado","config",configPath,"config_bytes",len(configData),"pid",os.Getpid())
	slog.Info("caminhos do serviço","state_dir",paths.StateDir,"runtime_dir",paths.RuntimeDir,"routes_dir",paths.RoutesDir,"llama_socket",paths.LlamaSocket,"generate_socket",paths.GenerateSocket)

	signals:=make(chan os.Signal,1);signal.Notify(signals,os.Interrupt,syscall.SIGTERM);defer signal.Stop(signals)
	sig:=<-signals
	slog.Info("sinal de encerramento recebido","signal",sig.String())
	slog.Info("ai-bash-gen encerrado")
	return 0
}
