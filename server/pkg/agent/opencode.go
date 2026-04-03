package agent

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// opencodeBackend implements Backend by spawning the OpenCode CLI
// with `opencode run --format json`.
type opencodeBackend struct {
	cfg Config
}

func (b *opencodeBackend) Execute(ctx context.Context, prompt string, opts ExecOptions) (*Session, error) {
	execPath := b.cfg.ExecutablePath
	if execPath == "" {
		execPath = "opencode"
	}
	if _, err := exec.LookPath(execPath); err != nil {
		return nil, fmt.Errorf("opencode executable not found at %q: %w", execPath, err)
	}

	timeout := opts.Timeout
	if timeout == 0 {
		timeout = 20 * time.Minute
	}
	runCtx, cancel := context.WithTimeout(ctx, timeout)

	args := []string{"run", "--format", "json"}
	if opts.Model != "" {
		args = append(args, "--model", opts.Model)
	}
	args = append(args, prompt)

	cmd := exec.CommandContext(runCtx, execPath, args...)
	if opts.Cwd != "" {
		cmd.Dir = opts.Cwd
	}
	cmd.Env = buildEnv(b.cfg.Env)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		cancel()
		return nil, fmt.Errorf("opencode stdout pipe: %w", err)
	}
	cmd.Stderr = newLogWriter(b.cfg.Logger, "[opencode:stderr] ")

	if err := cmd.Start(); err != nil {
		cancel()
		return nil, fmt.Errorf("start opencode: %w", err)
	}

	b.cfg.Logger.Info("opencode started", "pid", cmd.Process.Pid, "cwd", opts.Cwd, "model", opts.Model)

	msgCh := make(chan Message, 256)
	resCh := make(chan Result, 1)

	go func() {
		defer cancel()
		defer close(msgCh)
		defer close(resCh)

		startTime := time.Now()
		var output strings.Builder
		var sessionID string
		finalStatus := "completed"
		var finalError string

		scanner := bufio.NewScanner(stdout)
		scanner.Buffer(make([]byte, 0, 1024*1024), 10*1024*1024)

		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" {
				continue
			}

			var evt opencodeEvent
			if err := json.Unmarshal([]byte(line), &evt); err != nil {
				continue
			}

			if evt.SessionID != "" && sessionID == "" {
				sessionID = evt.SessionID
			}

			switch evt.Type {
			case "text":
				b.handleText(evt, msgCh, &output)
			case "tool_use":
				b.handleToolUse(evt, msgCh)
			case "step_start":
				trySend(msgCh, Message{Type: MessageStatus, Status: "running"})
			case "step_finish":
				b.handleStepFinish(evt, msgCh)
			case "error":
				b.handleError(evt, msgCh, &finalStatus, &finalError)
			}
		}

		// Wait for process exit
		exitErr := cmd.Wait()
		duration := time.Since(startTime)

		if runCtx.Err() == context.DeadlineExceeded {
			finalStatus = "timeout"
			finalError = fmt.Sprintf("opencode timed out after %s", timeout)
		} else if runCtx.Err() == context.Canceled {
			finalStatus = "aborted"
			finalError = "execution cancelled"
		} else if exitErr != nil && finalStatus == "completed" {
			finalStatus = "failed"
			finalError = fmt.Sprintf("opencode exited with error: %v", exitErr)
		}

		b.cfg.Logger.Info("opencode finished", "pid", cmd.Process.Pid, "status", finalStatus, "duration", duration.Round(time.Millisecond).String())

		resCh <- Result{
			Status:     finalStatus,
			Output:     output.String(),
			Error:      finalError,
			DurationMs: duration.Milliseconds(),
			SessionID:  sessionID,
		}
	}()

	return &Session{Messages: msgCh, Result: resCh}, nil
}

func (b *opencodeBackend) handleText(evt opencodeEvent, ch chan<- Message, output *strings.Builder) {
	text := evt.Part.Text
	if text == "" {
		return
	}

	partType := evt.Part.Type
	switch partType {
	case "thinking":
		trySend(ch, Message{Type: MessageThinking, Content: text})
	default:
		// "text" or any other type → treat as assistant text output
		output.WriteString(text)
		trySend(ch, Message{Type: MessageText, Content: text})
	}
}

func (b *opencodeBackend) handleToolUse(evt opencodeEvent, ch chan<- Message) {
	tool := evt.Part.Tool
	callID := evt.Part.CallID
	state := evt.Part.State

	var input map[string]any
	if state.Input != nil {
		_ = json.Unmarshal(state.Input, &input)
	}

	if state.Status == "completed" {
		// Emit both tool_use and tool_result for completed tool calls
		trySend(ch, Message{
			Type:   MessageToolUse,
			Tool:   tool,
			CallID: callID,
			Input:  input,
		})
		trySend(ch, Message{
			Type:   MessageToolResult,
			Tool:   tool,
			CallID: callID,
			Output: state.Output,
		})
	} else {
		// Running or pending tool call
		trySend(ch, Message{
			Type:   MessageToolUse,
			Tool:   tool,
			CallID: callID,
			Input:  input,
		})
	}
}

func (b *opencodeBackend) handleStepFinish(evt opencodeEvent, ch chan<- Message) {
	reason := evt.Part.Reason
	status := "step completed"
	if reason != "" {
		status = fmt.Sprintf("step finished: %s", reason)
	}
	trySend(ch, Message{Type: MessageStatus, Status: status})
}

func (b *opencodeBackend) handleError(evt opencodeEvent, ch chan<- Message, finalStatus, finalError *string) {
	errMsg := ""
	if evt.Error != nil {
		errMsg = evt.Error.Name
		if evt.Error.Data.Message != "" {
			errMsg = evt.Error.Data.Message
		}
	}
	if errMsg != "" {
		*finalStatus = "failed"
		*finalError = errMsg
		trySend(ch, Message{Type: MessageError, Content: errMsg})
	}
}

// ── OpenCode JSON event types ──

// opencodeEvent represents a single JSONL event from `opencode run --format json`.
type opencodeEvent struct {
	Type      string           `json:"type"`
	Timestamp int64            `json:"timestamp,omitempty"`
	SessionID string           `json:"sessionID,omitempty"`
	Part      opencodePartData `json:"part"`
	Error     *opencodeError   `json:"error,omitempty"`
}

// opencodePartData holds the "part" payload — its fields vary by event type.
type opencodePartData struct {
	ID        string          `json:"id,omitempty"`
	SessionID string          `json:"sessionID,omitempty"`
	MessageID string          `json:"messageID,omitempty"`
	Type      string          `json:"type,omitempty"`   // "text", "thinking", "step-start", "step-finish"
	Text      string          `json:"text,omitempty"`   // for text events
	Tool      string          `json:"tool,omitempty"`   // for tool_use events (e.g. "bash", "read")
	CallID    string          `json:"callID,omitempty"` // unique tool call ID
	Snapshot  string          `json:"snapshot,omitempty"`
	Reason    string          `json:"reason,omitempty"` // "stop", "tool-calls" — for step_finish
	Cost      float64         `json:"cost,omitempty"`

	State opencodeToolState `json:"state"` // for tool_use events

	Tokens *opencodeTokens `json:"tokens,omitempty"`
}

// opencodeToolState holds tool execution state within a tool_use event.
type opencodeToolState struct {
	Status   string          `json:"status,omitempty"` // "completed", "running"
	Input    json.RawMessage `json:"input,omitempty"`
	Output   string          `json:"output,omitempty"`
	Title    string          `json:"title,omitempty"`
	Time     float64         `json:"time,omitempty"`
	Metadata json.RawMessage `json:"metadata,omitempty"`
}

// opencodeTokens tracks token usage from step_finish events.
type opencodeTokens struct {
	Input     int `json:"input,omitempty"`
	Output    int `json:"output,omitempty"`
	Reasoning int `json:"reasoning,omitempty"`
	Cache     int `json:"cache,omitempty"`
}

// opencodeError holds error details from error events.
type opencodeError struct {
	Name string `json:"name,omitempty"`
	Data struct {
		Message string `json:"message,omitempty"`
	} `json:"data,omitempty"`
}
