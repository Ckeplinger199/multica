package handler

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/robfig/cron/v3"

	"github.com/multica-ai/multica/server/internal/logger"
	db "github.com/multica-ai/multica/server/pkg/db/generated"
	"github.com/multica-ai/multica/server/pkg/protocol"
)

// ---------------------------------------------------------------------------
// Response types
// ---------------------------------------------------------------------------

type AgentflowResponse struct {
	ID                string  `json:"id"`
	WorkspaceID       string  `json:"workspace_id"`
	AgentID           string  `json:"agent_id"`
	Title             string  `json:"title"`
	Description       string  `json:"description"`
	Status            string  `json:"status"`
	ConcurrencyPolicy string  `json:"concurrency_policy"`
	CreatedBy         *string `json:"created_by"`
	CreatedAt         string  `json:"created_at"`
	UpdatedAt         string  `json:"updated_at"`
}

type AgentflowTriggerResponse struct {
	ID          string  `json:"id"`
	AgentflowID string  `json:"agentflow_id"`
	Kind        string  `json:"kind"`
	Config      any     `json:"config"`
	Enabled     bool    `json:"enabled"`
	NextRunAt   *string `json:"next_run_at"`
	CreatedAt   string  `json:"created_at"`
	UpdatedAt   string  `json:"updated_at"`
}

type AgentflowRunResponse struct {
	ID            string  `json:"id"`
	AgentflowID   string  `json:"agentflow_id"`
	TriggerID     *string `json:"trigger_id"`
	AgentID       string  `json:"agent_id"`
	Status        string  `json:"status"`
	TaskID        *string `json:"task_id"`
	LinkedIssueID *string `json:"linked_issue_id"`
	Output        *string `json:"output"`
	Error         *string `json:"error"`
	StartedAt     *string `json:"started_at"`
	CompletedAt   *string `json:"completed_at"`
	CreatedAt     string  `json:"created_at"`
}

// ---------------------------------------------------------------------------
// Converters
// ---------------------------------------------------------------------------

func agentflowToResponse(af db.Agentflow) AgentflowResponse {
	return AgentflowResponse{
		ID:                uuidToString(af.ID),
		WorkspaceID:       uuidToString(af.WorkspaceID),
		AgentID:           uuidToString(af.AgentID),
		Title:             af.Title,
		Description:       af.Description,
		Status:            af.Status,
		ConcurrencyPolicy: af.ConcurrencyPolicy,
		CreatedBy:         uuidToPtr(af.CreatedBy),
		CreatedAt:         timestampToString(af.CreatedAt),
		UpdatedAt:         timestampToString(af.UpdatedAt),
	}
}

func agentflowTriggerToResponse(t db.AgentflowTrigger) AgentflowTriggerResponse {
	var cfg any
	if t.Config != nil {
		json.Unmarshal(t.Config, &cfg)
	}
	if cfg == nil {
		cfg = map[string]any{}
	}
	return AgentflowTriggerResponse{
		ID:          uuidToString(t.ID),
		AgentflowID: uuidToString(t.AgentflowID),
		Kind:        t.Kind,
		Config:      cfg,
		Enabled:     t.Enabled,
		NextRunAt:   timestampToPtr(t.NextRunAt),
		CreatedAt:   timestampToString(t.CreatedAt),
		UpdatedAt:   timestampToString(t.UpdatedAt),
	}
}

func agentflowRunToResponse(r db.AgentflowRun) AgentflowRunResponse {
	return AgentflowRunResponse{
		ID:            uuidToString(r.ID),
		AgentflowID:   uuidToString(r.AgentflowID),
		TriggerID:     uuidToPtr(r.TriggerID),
		AgentID:       uuidToString(r.AgentID),
		Status:        r.Status,
		TaskID:        uuidToPtr(r.TaskID),
		LinkedIssueID: uuidToPtr(r.LinkedIssueID),
		Output:        textToPtr(r.Output),
		Error:         textToPtr(r.Error),
		StartedAt:     timestampToPtr(r.StartedAt),
		CompletedAt:   timestampToPtr(r.CompletedAt),
		CreatedAt:     timestampToString(r.CreatedAt),
	}
}

// ---------------------------------------------------------------------------
// Cron helper
// ---------------------------------------------------------------------------

func computeNextRunAt(config map[string]any) (time.Time, error) {
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

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

// ListAgentflows returns all agentflows in the workspace.
func (h *Handler) ListAgentflows(w http.ResponseWriter, r *http.Request) {
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	flows, err := h.Queries.ListAgentflows(r.Context(), parseUUID(workspaceID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list agentflows")
		return
	}

	resp := make([]AgentflowResponse, len(flows))
	for i, af := range flows {
		resp[i] = agentflowToResponse(af)
	}
	writeJSON(w, http.StatusOK, resp)
}

// GetAgentflow returns a single agentflow by ID, validated against the workspace.
func (h *Handler) GetAgentflow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	af, err := h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          parseUUID(id),
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "agentflow not found")
		return
	}

	writeJSON(w, http.StatusOK, agentflowToResponse(af))
}

// CreateAgentflow creates a new agentflow with optional triggers.
func (h *Handler) CreateAgentflow(w http.ResponseWriter, r *http.Request) {
	workspaceID := resolveWorkspaceID(r)

	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	var req struct {
		Title             string `json:"title"`
		Description       string `json:"description"`
		AgentID           string `json:"agent_id"`
		ConcurrencyPolicy string `json:"concurrency_policy"`
		Triggers          []struct {
			Kind    string         `json:"kind"`
			Config  map[string]any `json:"config"`
			Enabled bool           `json:"enabled"`
		} `json:"triggers"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Title == "" {
		writeError(w, http.StatusBadRequest, "title is required")
		return
	}
	if req.AgentID == "" {
		writeError(w, http.StatusBadRequest, "agent_id is required")
		return
	}
	if req.ConcurrencyPolicy == "" {
		req.ConcurrencyPolicy = "allow"
	}

	// Validate agent exists in workspace.
	_, err := h.Queries.GetAgentInWorkspace(r.Context(), db.GetAgentInWorkspaceParams{
		ID:          parseUUID(req.AgentID),
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, "agent not found in workspace")
		return
	}

	af, err := h.Queries.CreateAgentflow(r.Context(), db.CreateAgentflowParams{
		WorkspaceID:       parseUUID(workspaceID),
		AgentID:           parseUUID(req.AgentID),
		Title:             req.Title,
		Description:       req.Description,
		Status:            "active",
		ConcurrencyPolicy: req.ConcurrencyPolicy,
		CreatedBy:         parseUUID(userID),
	})
	if err != nil {
		slog.Warn("create agentflow failed", append(logger.RequestAttrs(r), "error", err, "workspace_id", workspaceID)...)
		writeError(w, http.StatusInternalServerError, "failed to create agentflow")
		return
	}

	// Create triggers.
	for _, t := range req.Triggers {
		configBytes, _ := json.Marshal(t.Config)

		var nextRunAt pgtype.Timestamptz
		if t.Kind == "schedule" && t.Enabled {
			if next, err := computeNextRunAt(t.Config); err == nil {
				nextRunAt = pgtype.Timestamptz{Time: next, Valid: true}
			}
		}

		_, err := h.Queries.CreateAgentflowTrigger(r.Context(), db.CreateAgentflowTriggerParams{
			AgentflowID: af.ID,
			Kind:        t.Kind,
			Config:      configBytes,
			Enabled:     t.Enabled,
			NextRunAt:   nextRunAt,
		})
		if err != nil {
			slog.Warn("create agentflow trigger failed", append(logger.RequestAttrs(r), "error", err, "agentflow_id", uuidToString(af.ID))...)
		}
	}

	slog.Info("agentflow created", append(logger.RequestAttrs(r), "agentflow_id", uuidToString(af.ID), "workspace_id", workspaceID)...)

	resp := agentflowToResponse(af)
	actorType, actorID := h.resolveActor(r, userID, workspaceID)
	h.publish(protocol.EventAgentflowCreated, workspaceID, actorType, actorID, map[string]any{"agentflow": resp})
	writeJSON(w, http.StatusCreated, resp)
}

// UpdateAgentflow updates an existing agentflow.
func (h *Handler) UpdateAgentflow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	// Verify agentflow belongs to workspace.
	existing, err := h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          parseUUID(id),
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "agentflow not found")
		return
	}

	var req struct {
		Title             *string `json:"title"`
		Description       *string `json:"description"`
		Status            *string `json:"status"`
		AgentID           *string `json:"agent_id"`
		ConcurrencyPolicy *string `json:"concurrency_policy"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	params := db.UpdateAgentflowParams{
		ID: existing.ID,
	}
	if req.Title != nil {
		params.Title = pgtype.Text{String: *req.Title, Valid: true}
	}
	if req.Description != nil {
		params.Description = pgtype.Text{String: *req.Description, Valid: true}
	}
	if req.Status != nil {
		params.Status = pgtype.Text{String: *req.Status, Valid: true}
	}
	if req.ConcurrencyPolicy != nil {
		params.ConcurrencyPolicy = pgtype.Text{String: *req.ConcurrencyPolicy, Valid: true}
	}
	if req.AgentID != nil {
		// Validate agent exists in workspace.
		_, err := h.Queries.GetAgentInWorkspace(r.Context(), db.GetAgentInWorkspaceParams{
			ID:          parseUUID(*req.AgentID),
			WorkspaceID: parseUUID(workspaceID),
		})
		if err != nil {
			writeError(w, http.StatusBadRequest, "agent not found in workspace")
			return
		}
		params.AgentID = parseUUID(*req.AgentID)
	}

	af, err := h.Queries.UpdateAgentflow(r.Context(), params)
	if err != nil {
		slog.Warn("update agentflow failed", append(logger.RequestAttrs(r), "error", err, "agentflow_id", id)...)
		writeError(w, http.StatusInternalServerError, "failed to update agentflow")
		return
	}

	slog.Info("agentflow updated", append(logger.RequestAttrs(r), "agentflow_id", id, "workspace_id", workspaceID)...)

	resp := agentflowToResponse(af)
	userID := requestUserID(r)
	actorType, actorID := h.resolveActor(r, userID, workspaceID)
	h.publish(protocol.EventAgentflowUpdated, workspaceID, actorType, actorID, map[string]any{"agentflow": resp})
	writeJSON(w, http.StatusOK, resp)
}

// DeleteAgentflow deletes an agentflow and its triggers/runs (via cascade).
func (h *Handler) DeleteAgentflow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	// Verify agentflow belongs to workspace.
	af, err := h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          parseUUID(id),
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "agentflow not found")
		return
	}

	if err := h.Queries.DeleteAgentflow(r.Context(), af.ID); err != nil {
		slog.Warn("delete agentflow failed", append(logger.RequestAttrs(r), "error", err, "agentflow_id", id)...)
		writeError(w, http.StatusInternalServerError, "failed to delete agentflow")
		return
	}

	slog.Info("agentflow deleted", append(logger.RequestAttrs(r), "agentflow_id", id, "workspace_id", workspaceID)...)

	userID := requestUserID(r)
	actorType, actorID := h.resolveActor(r, userID, workspaceID)
	h.publish(protocol.EventAgentflowDeleted, workspaceID, actorType, actorID, map[string]any{"agentflow_id": id})
	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// TriggerAgentflowRun manually triggers an agentflow run.
func (h *Handler) TriggerAgentflowRun(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	af, err := h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          parseUUID(id),
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "agentflow not found")
		return
	}

	// Check concurrency policy.
	if af.ConcurrencyPolicy == "skip_if_active" {
		hasActive, err := h.Queries.HasActiveAgentflowRun(r.Context(), af.ID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to check active runs")
			return
		}
		if hasActive {
			writeError(w, http.StatusConflict, "an active run already exists for this agentflow")
			return
		}
	}

	// Create the run (manual trigger — no trigger_id).
	run, err := h.Queries.CreateAgentflowRun(r.Context(), db.CreateAgentflowRunParams{
		AgentflowID: af.ID,
		AgentID:     af.AgentID,
	})  // TriggerID left as zero-value (NULL)
	if err != nil {
		slog.Warn("create agentflow run failed", append(logger.RequestAttrs(r), "error", err, "agentflow_id", id)...)
		writeError(w, http.StatusInternalServerError, "failed to create agentflow run")
		return
	}

	// Enqueue a task for the agent.
	_, err = h.TaskService.EnqueueTaskForAgentflow(r.Context(), af, run.ID)
	if err != nil {
		slog.Warn("enqueue agentflow task failed", append(logger.RequestAttrs(r), "error", err, "agentflow_id", id, "run_id", uuidToString(run.ID))...)
		writeError(w, http.StatusInternalServerError, "failed to enqueue task: "+err.Error())
		return
	}

	slog.Info("agentflow run triggered", append(logger.RequestAttrs(r), "agentflow_id", id, "run_id", uuidToString(run.ID))...)

	resp := agentflowRunToResponse(run)
	userID := requestUserID(r)
	actorType, actorID := h.resolveActor(r, userID, workspaceID)
	h.publish(protocol.EventAgentflowRunCreated, workspaceID, actorType, actorID, map[string]any{"agentflow_run": resp})
	writeJSON(w, http.StatusCreated, resp)
}

// ListAgentflowRuns returns the run history for an agentflow.
func (h *Handler) ListAgentflowRuns(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	// Verify agentflow belongs to workspace.
	_, err := h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          parseUUID(id),
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "agentflow not found")
		return
	}

	limit := int32(50)
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 100 {
			limit = int32(n)
		}
	}
	offset := int32(0)
	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = int32(n)
		}
	}

	runs, err := h.Queries.ListAgentflowRuns(r.Context(), db.ListAgentflowRunsParams{
		AgentflowID: parseUUID(id),
		Limit:       limit,
		Offset:      offset,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list agentflow runs")
		return
	}

	resp := make([]AgentflowRunResponse, len(runs))
	for i, run := range runs {
		resp[i] = agentflowRunToResponse(run)
	}
	writeJSON(w, http.StatusOK, resp)
}

// CreateAgentflowTrigger adds a trigger to an agentflow.
func (h *Handler) CreateAgentflowTrigger(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	// Verify agentflow belongs to workspace.
	af, err := h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          parseUUID(id),
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "agentflow not found")
		return
	}

	var req struct {
		Kind    string         `json:"kind"`
		Config  map[string]any `json:"config"`
		Enabled bool           `json:"enabled"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Kind == "" {
		writeError(w, http.StatusBadRequest, "kind is required")
		return
	}

	configBytes, _ := json.Marshal(req.Config)

	var nextRunAt pgtype.Timestamptz
	if req.Kind == "schedule" && req.Enabled {
		if next, err := computeNextRunAt(req.Config); err == nil {
			nextRunAt = pgtype.Timestamptz{Time: next, Valid: true}
		}
	}

	trigger, err := h.Queries.CreateAgentflowTrigger(r.Context(), db.CreateAgentflowTriggerParams{
		AgentflowID: af.ID,
		Kind:        req.Kind,
		Config:      configBytes,
		Enabled:     req.Enabled,
		NextRunAt:   nextRunAt,
	})
	if err != nil {
		slog.Warn("create agentflow trigger failed", append(logger.RequestAttrs(r), "error", err, "agentflow_id", id)...)
		writeError(w, http.StatusInternalServerError, "failed to create trigger")
		return
	}

	writeJSON(w, http.StatusCreated, agentflowTriggerToResponse(trigger))
}

// UpdateAgentflowTrigger updates a trigger.
func (h *Handler) UpdateAgentflowTrigger(w http.ResponseWriter, r *http.Request) {
	triggerID := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	// Load trigger and verify it belongs to an agentflow in this workspace.
	existing, err := h.Queries.GetAgentflowTrigger(r.Context(), parseUUID(triggerID))
	if err != nil {
		writeError(w, http.StatusNotFound, "trigger not found")
		return
	}
	_, err = h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          existing.AgentflowID,
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "trigger not found")
		return
	}

	var req struct {
		Config  map[string]any `json:"config"`
		Enabled *bool          `json:"enabled"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	params := db.UpdateAgentflowTriggerParams{
		ID: existing.ID,
	}
	if req.Config != nil {
		configBytes, _ := json.Marshal(req.Config)
		params.Config = configBytes
	}
	if req.Enabled != nil {
		params.Enabled = *req.Enabled
	}

	// Recompute next_run_at for schedule triggers.
	effectiveEnabled := existing.Enabled
	if req.Enabled != nil {
		effectiveEnabled = *req.Enabled
	}
	effectiveConfig := req.Config
	if effectiveConfig == nil {
		// Parse existing config.
		var c map[string]any
		json.Unmarshal(existing.Config, &c)
		effectiveConfig = c
	}
	if existing.Kind == "schedule" && effectiveEnabled && effectiveConfig != nil {
		if next, err := computeNextRunAt(effectiveConfig); err == nil {
			params.NextRunAt = pgtype.Timestamptz{Time: next, Valid: true}
		}
	}

	trigger, err := h.Queries.UpdateAgentflowTrigger(r.Context(), params)
	if err != nil {
		slog.Warn("update agentflow trigger failed", append(logger.RequestAttrs(r), "error", err, "trigger_id", triggerID)...)
		writeError(w, http.StatusInternalServerError, "failed to update trigger")
		return
	}

	writeJSON(w, http.StatusOK, agentflowTriggerToResponse(trigger))
}

// DeleteAgentflowTrigger deletes a trigger.
func (h *Handler) DeleteAgentflowTrigger(w http.ResponseWriter, r *http.Request) {
	triggerID := chi.URLParam(r, "id")
	workspaceID := resolveWorkspaceID(r)
	if _, ok := h.workspaceMember(w, r, workspaceID); !ok {
		return
	}

	// Load trigger and verify it belongs to an agentflow in this workspace.
	existing, err := h.Queries.GetAgentflowTrigger(r.Context(), parseUUID(triggerID))
	if err != nil {
		writeError(w, http.StatusNotFound, "trigger not found")
		return
	}
	_, err = h.Queries.GetAgentflowInWorkspace(r.Context(), db.GetAgentflowInWorkspaceParams{
		ID:          existing.AgentflowID,
		WorkspaceID: parseUUID(workspaceID),
	})
	if err != nil {
		writeError(w, http.StatusNotFound, "trigger not found")
		return
	}

	if err := h.Queries.DeleteAgentflowTrigger(r.Context(), existing.ID); err != nil {
		slog.Warn("delete agentflow trigger failed", append(logger.RequestAttrs(r), "error", err, "trigger_id", triggerID)...)
		writeError(w, http.StatusInternalServerError, "failed to delete trigger")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}
