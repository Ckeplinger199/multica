-- Revert to original non-LOWER indexes.
DO $$
BEGIN
  DROP INDEX IF EXISTS idx_issue_title_bigm;
  DROP INDEX IF EXISTS idx_issue_description_bigm;
  DROP INDEX IF EXISTS idx_comment_content_bigm;

  CREATE INDEX idx_issue_title_bigm ON issue USING gin (title gin_bigm_ops);
  CREATE INDEX idx_issue_description_bigm ON issue USING gin (COALESCE(description, '') gin_bigm_ops);
  CREATE INDEX idx_comment_content_bigm ON comment USING gin (content gin_bigm_ops);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'skipping bigram index revert (pg_bigm not installed)';
END
$$;
