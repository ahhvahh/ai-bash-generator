package pipeline

import (
	"bufio"
	"fmt"
	"strconv"
	"strings"
)

type NormalizedTask struct {
	ID                string
	Instruction       string
	InputDescription  string
	OutputDescription string
}

type NormalizedRequest struct {
	Raw                  string
	Intent               string
	CanonicalInstruction string
	InputDescription     string
	OutputDescription    string
	FinalOutputRef       string
	Status               string
	Tasks                []NormalizedTask
}

const normalizerSystemPrompt = `You are the request-normalizer of ai-bash-gen.

Your job is to convert a user request written in any human language into a structured technical request.

You DO NOT generate Bash.
You DO NOT select shell commands.
You DO NOT execute anything.
You DO NOT search capabilities.
You DO NOT access databases or tools.

Translate semantic instructions to English while preserving all literal values exactly as provided by the user.

Your output must describe WHAT must be accomplished, never HOW to implement it.

Decompose the request into the smallest meaningful ordered tasks.

For each task:
- create a stable snake_case task id;
- describe the task in English;
- identify its required inputs;
- identify its output;
- reference outputs of previous tasks using result_ref;
- declare control dependencies using depends_on when necessary;
- preserve literal paths, filenames, service names, numbers and values exactly;
- do not invent missing information.

The complete request must contain:
- intent: a short semantic classification of the request;
- canonical_instruction: a precise technical description in English of the complete requested operation;
- input_description: description of the information or resources consumed;
- output_description: description of the expected final result;
- tasks: an ordered decomposition of the requested operation;
- final_output_ref: reference to the result produced by the final task.

Use the DataContract schema from ai_bash_gen.v1.NormalizedRequest.

If essential information is missing:
- set status to NORMALIZATION_STATUS_MISSING_INFORMATION;
- describe every missing input;
- never invent a value.

Otherwise:
- set status to NORMALIZATION_STATUS_READY.

Return ONLY a valid ai_bash_gen.v1.NormalizedRequest in protobuf text format.
Do not return Markdown.
Do not return explanations.`

func userRequestTextProto(text string) string {
	return "text: " + strconv.Quote(text)
}

func cleanTextProto(content string) string {
	content = strings.TrimSpace(content)
	if strings.HasPrefix(content, "```") {
		if i := strings.IndexByte(content, '\n'); i >= 0 {
			content = content[i+1:]
		}
		content = strings.TrimSpace(content)
		if strings.HasSuffix(content, "```") {
			content = strings.TrimSpace(strings.TrimSuffix(content, "```"))
		}
	}
	return content
}

func parseNormalizedRequest(content string) (NormalizedRequest, error) {
	raw := cleanTextProto(content)
	if raw == "" {
		return NormalizedRequest{}, fmt.Errorf("request-normalizer retornou conteúdo vazio")
	}

	result := NormalizedRequest{Raw: raw}
	scanner := bufio.NewScanner(strings.NewReader(raw))
	taskDepth := 0
	var current *NormalizedTask

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		if taskDepth == 0 && strings.HasPrefix(line, "tasks") && strings.Contains(line, "{") {
			taskDepth = braceDelta(line)
			if taskDepth <= 0 {
				taskDepth = 1
			}
			result.Tasks = append(result.Tasks, NormalizedTask{})
			current = &result.Tasks[len(result.Tasks)-1]
			continue
		}

		if taskDepth > 0 {
			if taskDepth == 1 && current != nil {
				if key, value, ok := textProtoField(line); ok {
					switch key {
					case "id":
						current.ID = value
					case "instruction":
						current.Instruction = value
					case "input_description":
						current.InputDescription = value
					case "output_description":
						current.OutputDescription = value
					}
				}
			}
			taskDepth += braceDelta(line)
			if taskDepth <= 0 {
				taskDepth = 0
				current = nil
			}
			continue
		}

		if key, value, ok := textProtoField(line); ok {
			switch key {
			case "intent":
				result.Intent = value
			case "canonical_instruction":
				result.CanonicalInstruction = value
			case "input_description":
				result.InputDescription = value
			case "output_description":
				result.OutputDescription = value
			case "final_output_ref":
				result.FinalOutputRef = value
			case "status":
				result.Status = value
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return NormalizedRequest{}, fmt.Errorf("ler resposta normalizada: %w", err)
	}

	if result.Status == "" {
		return NormalizedRequest{}, fmt.Errorf("NormalizedRequest sem status")
	}
	if result.CanonicalInstruction == "" {
		return NormalizedRequest{}, fmt.Errorf("NormalizedRequest sem canonical_instruction")
	}

	if result.Status == "NORMALIZATION_STATUS_READY" {
		if len(result.Tasks) == 0 {
			return NormalizedRequest{}, fmt.Errorf("NormalizedRequest READY sem tasks")
		}
		seen := make(map[string]struct{}, len(result.Tasks))
		for i, task := range result.Tasks {
			if task.ID == "" {
				return NormalizedRequest{}, fmt.Errorf("NormalizedRequest task %d sem id", i+1)
			}
			if task.Instruction == "" {
				return NormalizedRequest{}, fmt.Errorf("NormalizedRequest task %q sem instruction", task.ID)
			}
			if _, exists := seen[task.ID]; exists {
				return NormalizedRequest{}, fmt.Errorf("NormalizedRequest possui task id duplicado: %s", task.ID)
			}
			seen[task.ID] = struct{}{}
		}
	}
	return result, nil
}

func braceDelta(line string) int {
	return strings.Count(line, "{") - strings.Count(line, "}")
}

func textProtoField(line string) (string, string, bool) {
	if strings.Contains(line, "{") && !strings.Contains(line, ":") {
		return "", "", false
	}
	key, value, ok := strings.Cut(line, ":")
	if !ok {
		return "", "", false
	}
	key = strings.TrimSpace(key)
	value = strings.TrimSpace(value)
	if key == "" || value == "" {
		return "", "", false
	}
	if strings.HasPrefix(value, "\"") {
		if unquoted, err := strconv.Unquote(value); err == nil {
			value = unquoted
		}
	}
	return key, value, true
}

func passthroughNormalized(text string) NormalizedRequest {
	raw := fmt.Sprintf(`intent: "legacy_request"
canonical_instruction: %s
input_description: "User-provided request."
output_description: "Requested Bash behavior."
tasks {
  id: "fulfill_request"
  instruction: %s
  output {
    name: "result"
    contract {
      kind: DATA_KIND_TEXT
      encoding: STREAM_ENCODING_TEXT_UTF8
    }
  }
}
final_output_ref: "result"
status: NORMALIZATION_STATUS_READY`, strconv.Quote(text), strconv.Quote(text))
	parsed, _ := parseNormalizedRequest(raw)
	return parsed
}
