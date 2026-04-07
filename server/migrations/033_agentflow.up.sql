-- Agentflow tables and agent_task_queue extension for agentflow support.

-- Agentflows: reusable task templates for agents.
CREATE TABLE agentflow (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES agent(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused')),
    concurrency_policy TEXT NOT NULL DEFAULT 'allow' CHECK (concurrency_policy IN ('allow', 'skip_if_active')),
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_agentflow_workspace ON agentflow(workspace_id);
CREATE INDEX idx_agentflow_agent ON agentflow(agent_id);

-- Agentflow triggers: schedule, webhook, or API triggers.
CREATE TABLE agentflow_trigger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agentflow_id UUID NOT NULL REFERENCES agentflow(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('schedule', 'webhook', 'api')),
    config JSONB NOT NULL DEFAULT '{}',
    enabled BOOLEAN NOT NULL DEFAULT true,
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_agentflow_trigger_agentflow ON agentflow_trigger(agentflow_id);
CREATE INDEX idx_agentflow_trigger_schedule ON agentflow_trigger(kind, enabled, next_run_at)
    WHERE kind = 'schedule' AND enabled = true;

-- Agentflow runs: execution history.
CREATE TABLE agentflow_run (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agentflow_id UUID NOT NULL REFERENCES agentflow(id) ON DELETE CASCADE,
    trigger_id UUID REFERENCES agentflow_trigger(id) ON DELETE SET NULL,
    agent_id UUID NOT NULL REFERENCES agent(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    task_id UUID,
    linked_issue_id UUID,
    output TEXT,
    error TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_agentflow_run_agentflow ON agentflow_run(agentflow_id);
CREATE INDEX idx_agentflow_run_status ON agentflow_run(agentflow_id, status);

-- Extend agent_task_queue: make issue_id nullable, add agentflow_run_id.
ALTER TABLE agent_task_queue ALTER COLUMN issue_id DROP NOT NULL;
ALTER TABLE agent_task_queue ADD COLUMN agentflow_run_id UUID REFERENCES agentflow_run(id) ON DELETE SET NULL;
CREATE INDEX idx_agent_task_queue_agentflow_run ON agent_task_queue(agentflow_run_id) WHERE agentflow_run_id IS NOT NULL;
