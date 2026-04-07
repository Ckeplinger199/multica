package daemon

import (
	"fmt"
	"strings"
)

// BuildPrompt constructs the task prompt for an agent CLI.
// Keep this minimal — detailed instructions live in CLAUDE.md / AGENTS.md
// injected by execenv.InjectRuntimeConfig.
func BuildPrompt(task Task) string {
	var b strings.Builder
	b.WriteString("You are running as a local coding agent for a Multica workspace.\n\n")
	fmt.Fprintf(&b, "Your assigned issue ID is: %s\n\n", task.IssueID)
	fmt.Fprintf(&b, "Start by running `multica issue get %s --output json` to understand your task, then complete it.\n", task.IssueID)
	return b.String()
}

// BuildAgentflowPrompt constructs the task prompt for an agentflow execution.
func BuildAgentflowPrompt(task Task) string {
	var b strings.Builder
	b.WriteString("You are running as a local coding agent for a Multica workspace.\n\n")
	if task.Agentflow != nil {
		b.WriteString("## Task\n\n")
		b.WriteString(task.Agentflow.Description)
		b.WriteString("\n\n")
	}
	b.WriteString("You have access to the `multica` CLI to interact with the platform (create issues, post comments, etc.).\n")
	return b.String()
}
