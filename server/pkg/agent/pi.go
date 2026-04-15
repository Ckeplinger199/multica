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

// piBackend implements Backend by spawning the Pi CLI and parsing its
// JSONL event stream. Pi outputs structured events for agent lifecycle,
// message deltas, tool executions, and usage metrics.
type piBackend struct {
	cfg Config
}

func (b *piBackend) Execute(ctx context.Context, prompt string, opts ExecOptions) (*Session, error) {
	execPath := b.cfg.ExecutablePath
	if execPath == "" {
		execPath = "pi"
	}
	if _, err := exec.LookPath(execPath); err != nil {
		return nil, fmt.Errorf("pi executable not found at %q: %w", execPath, err)
	}

	timeout := opts.Timeout
	if timeout == 0 {
		timeout = 20 * time.Minute
	}
	runCtx, cancel := context.WithTimeout(ctx, timeout)

	args := buildPiArgs(prompt, opts)

	cmd := exec.CommandContext(runCtx, execPath, args...)
	cmd.WaitDelay = 10 * time.Second
	if opts.Cwd != "" {
		cmd.Dir = opts.Cwd
	}
	cmd.Env = buildEnv(b.cfg.Env)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		cancel()
		return nil, fmt.Errorf("pi stdout pipe: %w", err)
	}
	cmd.Stderr = newLogWriter(b.cfg.Logger, "[pi:stderr] ")

	if err := cmd.Start(); err != nil {
		cancel()
		return nil, fmt.Errorf("start pi: %w", err)
	}

	b.cfg.Logger.Info("pi started", "pid", cmd.Process.Pid, "cwd", opts.Cwd, "model", opts.Model)

	msgCh := make(chan Message, 256)
	resCh := make(chan Result, 1)

	// Close stdout when the context is cancelled so scanner.Scan() unblocks.
	go func() {
		<-runCtx.Done()
		_ = stdout.Close()
	}()

	go func() {
		defer cancel()
		defer close(msgCh)
		defer close(resCh)

		startTime := time.Now()
		var output strings.Builder
		var sessionID string
		finalStatus := "completed"
		var finalError string
		usage := make(map[string]TokenUsage)

		scanner := bufio.NewScanner(stdout)
		scanner.Buffer(make([]byte, 0, 1024*1024), 10*1024*1024)

		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" {
				continue
			}

			var evt piStreamEvent
			if err := json.Unmarshal([]byte(line), &evt); err != nil {
				continue
			}

			switch evt.Type {
			case "agent_start":
				if evt.SessionID != "" {
					sessionID = evt.SessionID
				}
				trySend(msgCh, Message{Type: MessageStatus, Status: "running"})

			case "message_update":
				if evt.Content != "" {
					output.WriteString(evt.Content)
					trySend(msgCh, Message{Type: MessageText, Content: evt.Content})
				}

			case "thinking_update":
				if evt.Content != "" {
					trySend(msgCh, Message{Type: MessageThinking, Content: evt.Content})
				}

			case "tool_execution_start":
				var params map[string]any
				if evt.Input != nil {
					_ = json.Unmarshal(evt.Input, &params)
				}
				trySend(msgCh, Message{
					Type:   MessageToolUse,
					Tool:   evt.ToolName,
					CallID: evt.ExecutionID,
					Input:  params,
				})

			case "tool_execution_end":
				trySend(msgCh, Message{
					Type:   MessageToolResult,
					CallID: evt.ExecutionID,
					Output: evt.Output,
				})

			case "error":
				trySend(msgCh, Message{
					Type:    MessageError,
					Content: evt.Message,
				})

			case "agent_end":
				if evt.SessionID != "" {
					sessionID = evt.SessionID
				}
				if evt.Error != "" {
					finalStatus = "failed"
					finalError = evt.Error
				}
				if evt.Usage != nil {
					b.accumulateUsage(usage, evt.Usage, opts.Model)
				}
			}
		}

		waitErr := cmd.Wait()
		duration := time.Since(startTime)

		if runCtx.Err() == context.DeadlineExceeded {
			finalStatus = "timeout"
			finalError = fmt.Sprintf("pi timed out after %s", timeout)
		} else if runCtx.Err() == context.Canceled {
			finalStatus = "aborted"
			finalError = "execution cancelled"
		} else if waitErr != nil && finalStatus == "completed" {
			finalStatus = "failed"
			finalError = fmt.Sprintf("pi exited with error: %v", waitErr)
		}

		b.cfg.Logger.Info("pi finished", "pid", cmd.Process.Pid, "status", finalStatus, "duration", duration.Round(time.Millisecond).String())

		resCh <- Result{
			Status:     finalStatus,
			Output:     output.String(),
			Error:      finalError,
			DurationMs: duration.Milliseconds(),
			SessionID:  sessionID,
			Usage:      usage,
		}
	}()

	return &Session{Messages: msgCh, Result: resCh}, nil
}

// accumulateUsage merges Pi usage data into the per-model usage map.
func (b *piBackend) accumulateUsage(usage map[string]TokenUsage, pu *piUsage, fallbackModel string) {
	model := pu.Model
	if model == "" {
		model = fallbackModel
	}
	if model == "" {
		model = "unknown"
	}
	u := usage[model]
	u.InputTokens += pu.InputTokens
	u.OutputTokens += pu.OutputTokens
	u.CacheReadTokens += pu.CachedInputTokens
	usage[model] = u
}

// ── Pi JSONL event types ──

type piStreamEvent struct {
	Type      string `json:"type"`
	Timestamp string `json:"timestamp,omitempty"`
	SessionID string `json:"session_id,omitempty"`

	// message_update / thinking_update
	Content string `json:"content,omitempty"`

	// tool_execution_start / tool_execution_end
	ToolName    string          `json:"tool_name,omitempty"`
	ExecutionID string          `json:"execution_id,omitempty"`
	Input       json.RawMessage `json:"input,omitempty"`
	Output      string          `json:"output,omitempty"`

	// error
	Message string `json:"message,omitempty"`

	// agent_end
	Error string   `json:"error,omitempty"`
	Usage *piUsage `json:"usage,omitempty"`
}

type piUsage struct {
	Model             string `json:"model,omitempty"`
	InputTokens       int64  `json:"input_tokens"`
	OutputTokens      int64  `json:"output_tokens"`
	CachedInputTokens int64  `json:"cached_input_tokens"`
}

// ── Arg builder ──

// buildPiArgs assembles the argv for a one-shot Pi invocation.
//
// Flags:
//
//	-p <prompt>                 non-interactive prompt (the user's task)
//	--output-format jsonl       JSONL event stream for machine parsing
//	--yolo                      auto-approve all tool executions
//	--provider <name> --model <id>  model selection
//	--session <id>              resume a previous session
//	--append-system-prompt <text>   additional system instructions
func buildPiArgs(prompt string, opts ExecOptions) []string {
	args := []string{
		"-p", prompt,
		"--output-format", "jsonl",
		"--yolo",
	}
	if opts.Model != "" {
		args = append(args, "--model", opts.Model)
	}
	if opts.SystemPrompt != "" {
		args = append(args, "--append-system-prompt", opts.SystemPrompt)
	}
	if opts.ResumeSessionID != "" {
		args = append(args, "--session", opts.ResumeSessionID)
	}
	if opts.MaxTurns > 0 {
		args = append(args, "--max-turns", fmt.Sprintf("%d", opts.MaxTurns))
	}
	return args
}
