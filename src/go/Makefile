APP := ai-bash-gen
BIN_DIR := bin
PROTO_ROOT := ../../proto
PROTO_FILE := $(PROTO_ROOT)/ai_bash_gen/v1/pipeline.proto
MODULE := github.com/ahhvahh/ai-bash-generator

.PHONY: build test fmt vet clean tools proto

build:
	mkdir -p $(BIN_DIR)
	go build -trimpath -o $(BIN_DIR)/$(APP) ./cmd/ai-bash-gen

test:
	go test ./...

fmt:
	gofmt -w ./cmd ./internal

vet:
	go vet ./...

tools:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.6

proto:
	@command -v protoc >/dev/null || (echo 'protoc não encontrado. Debian: sudo apt install protobuf-compiler' && exit 1)
	@command -v protoc-gen-go >/dev/null || (echo 'protoc-gen-go não encontrado. Execute: make tools' && exit 1)
	protoc -I $(PROTO_ROOT) --go_out=. --go_opt=module=$(MODULE) $(PROTO_FILE)
	go mod tidy

clean:
	rm -rf $(BIN_DIR) gen
