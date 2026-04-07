-- Re-add the triggers column to agent table.
ALTER TABLE agent ADD COLUMN triggers JSONB NOT NULL DEFAULT '[]';
