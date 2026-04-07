-- Remove the triggers column from agent table.
-- Trigger behavior (on_assign, on_comment, on_mention) is now always enabled (hardcoded).
ALTER TABLE agent DROP COLUMN IF EXISTS triggers;
