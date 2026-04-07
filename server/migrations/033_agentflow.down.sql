-- Revert agentflow changes.
DROP INDEX IF EXISTS idx_agent_task_queue_agentflow_run;
ALTER TABLE agent_task_queue DROP COLUMN IF EXISTS agentflow_run_id;
-- Restore issue_id NOT NULL (must remove rows with NULL issue_id first).
DELETE FROM agent_task_queue WHERE issue_id IS NULL;
ALTER TABLE agent_task_queue ALTER COLUMN issue_id SET NOT NULL;

DROP TABLE IF EXISTS agentflow_run;
DROP TABLE IF EXISTS agentflow_trigger;
DROP TABLE IF EXISTS agentflow;
