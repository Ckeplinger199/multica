-- name: ListAgentflows :many
SELECT * FROM agentflow
WHERE workspace_id = $1
ORDER BY created_at DESC;

-- name: GetAgentflow :one
SELECT * FROM agentflow WHERE id = $1;

-- name: GetAgentflowInWorkspace :one
SELECT * FROM agentflow WHERE id = $1 AND workspace_id = $2;

-- name: CreateAgentflow :one
INSERT INTO agentflow (workspace_id, agent_id, title, description, status, concurrency_policy, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: UpdateAgentflow :one
UPDATE agentflow SET
    title = COALESCE(sqlc.narg('title'), title),
    description = COALESCE(sqlc.narg('description'), description),
    status = COALESCE(sqlc.narg('status'), status),
    concurrency_policy = COALESCE(sqlc.narg('concurrency_policy'), concurrency_policy),
    agent_id = COALESCE(sqlc.narg('agent_id'), agent_id),
    updated_at = now()
WHERE id = @id
RETURNING *;

-- name: DeleteAgentflow :exec
DELETE FROM agentflow WHERE id = $1;

-- Triggers ------------------------------------------------------------------

-- name: CreateAgentflowTrigger :one
INSERT INTO agentflow_trigger (agentflow_id, kind, config, enabled, next_run_at)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetAgentflowTrigger :one
SELECT * FROM agentflow_trigger WHERE id = $1;

-- name: ListAgentflowTriggers :many
SELECT * FROM agentflow_trigger
WHERE agentflow_id = $1
ORDER BY created_at ASC;

-- name: UpdateAgentflowTrigger :one
UPDATE agentflow_trigger SET
    config = COALESCE($2, config),
    enabled = COALESCE($3, enabled),
    next_run_at = COALESCE($4, next_run_at),
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: DeleteAgentflowTrigger :exec
DELETE FROM agentflow_trigger WHERE id = $1;

-- Compare-and-swap update for next_run_at to prevent duplicate firing.
-- name: CASUpdateTriggerNextRun :one
UPDATE agentflow_trigger
SET next_run_at = @new_next_run_at
WHERE id = @id AND next_run_at = @old_next_run_at
RETURNING *;

-- Returns schedule triggers that are due to fire. Used by the scheduler goroutine.
-- name: ListDueScheduleTriggers :many
SELECT t.*, af.agent_id, af.workspace_id, af.title AS agentflow_title,
       af.description AS agentflow_description, af.concurrency_policy
FROM agentflow_trigger t
JOIN agentflow af ON af.id = t.agentflow_id
WHERE t.kind = 'schedule'
  AND t.enabled = true
  AND t.next_run_at <= now()
  AND af.status = 'active'
ORDER BY t.next_run_at ASC;

-- Runs -----------------------------------------------------------------------

-- name: CreateAgentflowRun :one
INSERT INTO agentflow_run (agentflow_id, trigger_id, agent_id, status)
VALUES ($1, $2, $3, 'pending')
RETURNING *;

-- name: GetAgentflowRun :one
SELECT * FROM agentflow_run WHERE id = $1;

-- name: ListAgentflowRuns :many
SELECT * FROM agentflow_run
WHERE agentflow_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: UpdateAgentflowRunStatus :one
UPDATE agentflow_run SET
    status = $2,
    started_at = CASE WHEN $2 = 'running' AND started_at IS NULL THEN now() ELSE started_at END,
    completed_at = CASE WHEN $2 IN ('completed', 'failed') THEN now() ELSE completed_at END
WHERE id = $1
RETURNING *;

-- name: UpdateAgentflowRunResult :one
UPDATE agentflow_run SET
    status = $2,
    output = $3,
    error = $4,
    task_id = $5,
    linked_issue_id = $6,
    completed_at = now()
WHERE id = $1
RETURNING *;

-- Used by concurrency_policy='skip_if_active' to check if a run is already in progress.
-- name: HasActiveAgentflowRun :one
SELECT count(*) > 0 AS has_active FROM agentflow_run
WHERE agentflow_id = $1 AND status IN ('pending', 'running');

-- name: SetAgentflowRunTaskID :exec
UPDATE agentflow_run SET task_id = $2 WHERE id = $1;

-- Task queue extensions -------------------------------------------------------
-- Creates a task for an agentflow run (no issue_id).
-- name: CreateAgentflowTask :one
INSERT INTO agent_task_queue (agent_id, runtime_id, issue_id, status, priority, agentflow_run_id)
VALUES ($1, $2, NULL, 'queued', 0, $3)
RETURNING *;

-- Claims the next queued agentflow task for an agent.
-- No per-issue serialization needed since agentflow tasks are independent.
-- name: ClaimAgentflowTask :one
UPDATE agent_task_queue
SET status = 'dispatched', dispatched_at = now()
WHERE id = (
    SELECT atq.id FROM agent_task_queue atq
    WHERE atq.agent_id = $1 AND atq.status = 'queued'
      AND atq.agentflow_run_id IS NOT NULL
    ORDER BY atq.priority DESC, atq.created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
)
RETURNING *;
