-- Rebuild pg_bigm GIN indexes on LOWER() expressions so that
-- LOWER(column) LIKE queries can use the index (pg_bigm 1.2 does not support ILIKE).
DO $$
BEGIN
  -- Drop old indexes that were on raw columns
  DROP INDEX IF EXISTS idx_issue_title_bigm;
  DROP INDEX IF EXISTS idx_issue_description_bigm;
  DROP INDEX IF EXISTS idx_comment_content_bigm;

  -- Recreate on LOWER() expressions
  CREATE INDEX idx_issue_title_bigm ON issue USING gin (LOWER(title) gin_bigm_ops);
  CREATE INDEX idx_issue_description_bigm ON issue USING gin (LOWER(COALESCE(description, '')) gin_bigm_ops);
  CREATE INDEX idx_comment_content_bigm ON comment USING gin (LOWER(content) gin_bigm_ops);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'skipping bigram index rebuild (pg_bigm not installed)';
END
$$;
