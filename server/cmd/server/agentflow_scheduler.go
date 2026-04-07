package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/robfig/cron/v3"

	"github.com/multica-ai/multica/server/internal/events"
	"github.com/multica-ai/multica/server/internal/service"
	"github.com/multica-ai/multica/server/internal/util"
	db "github.com/multica-ai/multica/server/pkg/db/generated"
	"github.com/multica-ai/multica/server/pkg/protocol"
)

const agentflowScheduleInterval = 30 * time.Second

// runAgentflowScheduler periodically checks for due schedule triggers and fires them.
func runAgentflowScheduler(ctx context.Context, queries *db.Queries, bus *events.Bus, taskSvc *service.TaskService) {
	ticker := time.NewTicker(agentflowScheduleInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			processScheduleTriggers(ctx, queries, bus, taskSvc)
		}
	}
}

func processScheduleTriggers(ctx context.Context, queries *db.Queries, bus *events.Bus, taskSvc *service.TaskService) {
	dueTriggers, err := queries.ListDueScheduleTriggers(ctx)
	if err != nil {
		slog.Warn("agentflow scheduler: failed to list due triggers", "error", err)
		return
	}
	if len(dueTriggers) == 0 {
		return
	}

	slog.Info("agentflow scheduler: found due triggers", "count", len(dueTriggers))

	for _, trigger := range dueTriggers {
		fireTrigger(ctx, queries, bus, taskSvc, trigger)
	}
}

func fireTrigger(ctx context.Context, queries *db.Queries, bus *events.Bus, taskSvc *service.TaskService, trigger db.ListDueScheduleTriggersRow) {
	triggerID := util.UUIDToString(trigger.ID)
	agentflowID := util.UUIDToString(trigger.AgentflowID)

	// Compute next_run_at from cron config.
	var config map[string]any
	if err := json.Unmarshal(trigger.Config, &config); err != nil {
		slog.Warn("agentflow scheduler: invalid trigger config", "trigger_id", triggerID, "error", err)
		return
	}

	nextRunAt, err := computeNextRun(config)
	if err != nil {
		slog.Warn("agentflow scheduler: cannot compute next run", "trigger_id", triggerID, "error", err)
		return
	}

	// CAS update to prevent double-firing.
	_, err = queries.CASUpdateTriggerNextRun(ctx, db.CASUpdateTriggerNextRunParams{
		ID:           trigger.ID,
		OldNextRunAt: trigger.NextRunAt,
		NewNextRunAt: pgtype.Timestamptz{Time: nextRunAt, Valid: true},
	})
	if err != nil {
		slog.Debug("agentflow scheduler: CAS failed (likely claimed by another instance)", "trigger_id", triggerID)
		return
	}

	// Check concurrency policy.
	if trigger.ConcurrencyPolicy == "skip_if_active" {
		hasActive, err := queries.HasActiveAgentflowRun(ctx, trigger.AgentflowID)
		if err != nil {
			slog.Warn("agentflow scheduler: failed to check active runs", "trigger_id", triggerID, "error", err)
			return
		}
		if hasActive {
			slog.Info("agentflow scheduler: skipping (active run exists)", "agentflow_id", agentflowID)
			return
		}
	}

	// Load the full agentflow record for task enqueue.
	agentflow, err := queries.GetAgentflow(ctx, trigger.AgentflowID)
	if err != nil {
		slog.Warn("agentflow scheduler: failed to load agentflow", "agentflow_id", agentflowID, "error", err)
		return
	}

	// Create a run.
	run, err := queries.CreateAgentflowRun(ctx, db.CreateAgentflowRunParams{
		AgentflowID: trigger.AgentflowID,
		TriggerID:   trigger.ID,
		AgentID:     trigger.AgentID,
	})
	if err != nil {
		slog.Warn("agentflow scheduler: failed to create run", "agentflow_id", agentflowID, "error", err)
		return
	}

	// Enqueue the task (also links task_id back to the run).
	task, err := taskSvc.EnqueueTaskForAgentflow(ctx, agentflow, run.ID)
	if err != nil {
		slog.Warn("agentflow scheduler: failed to enqueue task", "agentflow_id", agentflowID, "run_id", util.UUIDToString(run.ID), "error", err)
		// Mark run as failed.
		queries.UpdateAgentflowRunResult(ctx, db.UpdateAgentflowRunResultParams{
			ID:     run.ID,
			Status: "failed",
			Error:  pgtype.Text{String: err.Error(), Valid: true},
		})
		return
	}

	slog.Info("agentflow scheduler: fired trigger",
		"trigger_id", triggerID,
		"agentflow_id", agentflowID,
		"run_id", util.UUIDToString(run.ID),
		"task_id", util.UUIDToString(task.ID),
	)

	// Broadcast event.
	bus.Publish(events.Event{
		Type:        protocol.EventAgentflowRunCreated,
		WorkspaceID: util.UUIDToString(agentflow.WorkspaceID),
		ActorType:   "system",
		Payload: map[string]any{
			"agentflow_id": agentflowID,
			"run_id":       util.UUIDToString(run.ID),
			"task_id":      util.UUIDToString(task.ID),
		},
	})
}

func computeNextRun(config map[string]any) (time.Time, error) {
	cronExpr, _ := config["cron"].(string)
	if cronExpr == "" {
		return time.Time{}, fmt.Errorf("missing cron expression")
	}
	tz, _ := config["timezone"].(string)
	if tz == "" {
		tz = "UTC"
	}
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid timezone: %w", err)
	}
	parser := cron.NewParser(cron.Minute | cron.Hour | cron.Dom | cron.Month | cron.Dow)
	schedule, err := parser.Parse(cronExpr)
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid cron expression: %w", err)
	}
	return schedule.Next(time.Now().In(loc)), nil
}
