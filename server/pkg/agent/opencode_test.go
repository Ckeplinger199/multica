package agent

import (
	"encoding/json"
	"log/slog"
	"strings"
	"testing"
)

func TestOpencodeHandleText(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)
	var output strings.Builder

	evt := opencodeEvent{
		Type:      "text",
		SessionID: "ses_abc123",
		Part: opencodePartData{
			Type: "text",
			Text: "Hello from OpenCode",
		},
	}

	b.handleText(evt, ch, &output)

	if output.String() != "Hello from OpenCode" {
		t.Fatalf("expected output 'Hello from OpenCode', got %q", output.String())
	}
	select {
	case m := <-ch:
		if m.Type != MessageText || m.Content != "Hello from OpenCode" {
			t.Fatalf("unexpected message: %+v", m)
		}
	default:
		t.Fatal("expected message on channel")
	}
}

func TestOpencodeHandleTextThinking(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)
	var output strings.Builder

	evt := opencodeEvent{
		Type: "text",
		Part: opencodePartData{
			Type: "thinking",
			Text: "Let me think about this...",
		},
	}

	b.handleText(evt, ch, &output)

	// Thinking text should NOT go to output
	if output.String() != "" {
		t.Fatalf("expected empty output for thinking, got %q", output.String())
	}
	select {
	case m := <-ch:
		if m.Type != MessageThinking || m.Content != "Let me think about this..." {
			t.Fatalf("unexpected message: %+v", m)
		}
	default:
		t.Fatal("expected message on channel")
	}
}

func TestOpencodeHandleTextEmpty(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)
	var output strings.Builder

	evt := opencodeEvent{
		Type: "text",
		Part: opencodePartData{Type: "text", Text: ""},
	}

	b.handleText(evt, ch, &output)

	if output.String() != "" {
		t.Fatalf("expected empty output, got %q", output.String())
	}
	select {
	case m := <-ch:
		t.Fatalf("expected no message for empty text, got %+v", m)
	default:
	}
}

func TestOpencodeHandleToolUseCompleted(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)

	evt := opencodeEvent{
		Type: "tool_use",
		Part: opencodePartData{
			Tool:   "bash",
			CallID: "call-42",
			State: opencodeToolState{
				Status: "completed",
				Input:  mustMarshal(t, map[string]any{"command": "ls -la"}),
				Output: "total 8\ndrwxr-xr-x 2 user user 4096 ...",
			},
		},
	}

	b.handleToolUse(evt, ch)

	// Should emit both tool_use and tool_result
	m1 := <-ch
	if m1.Type != MessageToolUse || m1.Tool != "bash" || m1.CallID != "call-42" {
		t.Fatalf("unexpected tool_use message: %+v", m1)
	}
	if m1.Input["command"] != "ls -la" {
		t.Fatalf("expected input command 'ls -la', got %v", m1.Input["command"])
	}

	m2 := <-ch
	if m2.Type != MessageToolResult || m2.CallID != "call-42" {
		t.Fatalf("unexpected tool_result message: %+v", m2)
	}
	if !strings.Contains(m2.Output, "total 8") {
		t.Fatalf("expected output containing 'total 8', got %q", m2.Output)
	}
}

func TestOpencodeHandleToolUseRunning(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)

	evt := opencodeEvent{
		Type: "tool_use",
		Part: opencodePartData{
			Tool:   "read",
			CallID: "call-99",
			State: opencodeToolState{
				Status: "running",
				Input:  mustMarshal(t, map[string]any{"path": "/tmp/test.go"}),
			},
		},
	}

	b.handleToolUse(evt, ch)

	// Should emit only tool_use (no result yet)
	m := <-ch
	if m.Type != MessageToolUse || m.Tool != "read" || m.CallID != "call-99" {
		t.Fatalf("unexpected message: %+v", m)
	}

	select {
	case extra := <-ch:
		t.Fatalf("expected no extra message for running tool, got %+v", extra)
	default:
	}
}

func TestOpencodeHandleStepFinish(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)

	evt := opencodeEvent{
		Type: "step_finish",
		Part: opencodePartData{
			Type:   "step-finish",
			Reason: "stop",
		},
	}

	b.handleStepFinish(evt, ch)

	m := <-ch
	if m.Type != MessageStatus || !strings.Contains(m.Status, "stop") {
		t.Fatalf("unexpected message: %+v", m)
	}
}

func TestOpencodeHandleError(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)

	finalStatus := "completed"
	finalError := ""

	evt := opencodeEvent{
		Type: "error",
		Error: &opencodeError{
			Name: "RateLimitError",
		},
	}
	evt.Error.Data.Message = "rate limit exceeded"

	b.handleError(evt, ch, &finalStatus, &finalError)

	if finalStatus != "failed" {
		t.Fatalf("expected status 'failed', got %q", finalStatus)
	}
	if finalError != "rate limit exceeded" {
		t.Fatalf("expected error 'rate limit exceeded', got %q", finalError)
	}

	m := <-ch
	if m.Type != MessageError || m.Content != "rate limit exceeded" {
		t.Fatalf("unexpected message: %+v", m)
	}
}

func TestOpencodeHandleErrorNameOnly(t *testing.T) {
	t.Parallel()

	b := &opencodeBackend{cfg: Config{Logger: slog.Default()}}
	ch := make(chan Message, 10)

	finalStatus := "completed"
	finalError := ""

	evt := opencodeEvent{
		Type: "error",
		Error: &opencodeError{
			Name: "UnknownError",
		},
	}

	b.handleError(evt, ch, &finalStatus, &finalError)

	if finalError != "UnknownError" {
		t.Fatalf("expected error 'UnknownError', got %q", finalError)
	}
}

func TestOpencodeEventParsing(t *testing.T) {
	t.Parallel()

	raw := `{"type":"text","timestamp":1767036059338,"sessionID":"ses_abc","part":{"type":"text","text":"Hello"}}`
	var evt opencodeEvent
	if err := json.Unmarshal([]byte(raw), &evt); err != nil {
		t.Fatalf("failed to parse event: %v", err)
	}

	if evt.Type != "text" {
		t.Fatalf("expected type 'text', got %q", evt.Type)
	}
	if evt.SessionID != "ses_abc" {
		t.Fatalf("expected sessionID 'ses_abc', got %q", evt.SessionID)
	}
	if evt.Part.Text != "Hello" {
		t.Fatalf("expected part.text 'Hello', got %q", evt.Part.Text)
	}
}

func TestOpencodeToolUseEventParsing(t *testing.T) {
	t.Parallel()

	raw := `{"type":"tool_use","timestamp":1767036060000,"sessionID":"ses_xyz","part":{"callID":"call-1","tool":"bash","state":{"status":"completed","input":{"command":"echo hi"},"output":"hi\n","time":0.5}}}`
	var evt opencodeEvent
	if err := json.Unmarshal([]byte(raw), &evt); err != nil {
		t.Fatalf("failed to parse event: %v", err)
	}

	if evt.Type != "tool_use" {
		t.Fatalf("expected type 'tool_use', got %q", evt.Type)
	}
	if evt.Part.Tool != "bash" {
		t.Fatalf("expected tool 'bash', got %q", evt.Part.Tool)
	}
	if evt.Part.CallID != "call-1" {
		t.Fatalf("expected callID 'call-1', got %q", evt.Part.CallID)
	}
	if evt.Part.State.Status != "completed" {
		t.Fatalf("expected state.status 'completed', got %q", evt.Part.State.Status)
	}
	if evt.Part.State.Output != "hi\n" {
		t.Fatalf("expected state.output 'hi\\n', got %q", evt.Part.State.Output)
	}
}
