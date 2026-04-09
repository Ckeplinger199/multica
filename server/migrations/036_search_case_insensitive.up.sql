-- Replace bigram indexes with LOWER() versions for case-insensitive search.
-- Only created when pg_bigm is installed.
DO $$
BEGIN
  DROP INDEX IF EXISTS idx_issue_title_bigm;
  DROP INDEX IF EXISTS idx_issue_description_bigm;
  CREATE INDEX idx_issue_title_bigm ON issue USING gin (LOWER(title) gin_bigm_ops);
  CREATE INDEX idx_issue_description_bigm ON issue USING gin (LOWER(COALESCE(description, '')) gin_bigm_ops);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'skipping bigram index rebuild (pg_bigm not installed)';
END
$$;

DO $$
BEGIN
  DROP INDEX IF EXISTS idx_comment_content_bigm;
  CREATE INDEX idx_comment_content_bigm ON comment USING gin (LOWER(content) gin_bigm_ops);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'skipping bigram index rebuild on comment (pg_bigm not installed)';
END
$$;
