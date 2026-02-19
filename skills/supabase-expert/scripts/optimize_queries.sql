-- Supabase Query Optimization Scripts
-- SEOcrawler V2 Performance Tuning

-- =====================================================
-- 1. ANALYZE SLOW QUERIES
-- =====================================================

-- Enable pg_stat_statements if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slowest queries
SELECT
    query,
    mean_exec_time,
    total_exec_time,
    calls,
    mean_exec_time / 1000 as mean_seconds,
    (total_exec_time / calls) / 1000 as avg_seconds
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 20;

-- =====================================================
-- 2. FIND MISSING INDEXES
-- =====================================================

-- Check for missing indexes on foreign keys
SELECT
    c.conname AS constraint_name,
    tbl.relname AS table_name,
    col.attname AS column_name,
    'CREATE INDEX idx_' || tbl.relname || '_' || col.attname ||
    ' ON ' || tbl.relname || '(' || col.attname || ');' AS create_index_sql
FROM pg_constraint c
JOIN pg_class tbl ON c.conrelid = tbl.oid
JOIN pg_attribute col ON col.attrelid = tbl.oid
    AND col.attnum = ANY(c.conkey)
WHERE c.contype = 'f'
    AND NOT EXISTS (
        SELECT 1
        FROM pg_index i
        WHERE i.indrelid = c.conrelid
            AND col.attnum = ANY(i.indkey)
    );

-- Find tables with sequential scans
SELECT
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    CASE
        WHEN seq_scan > 0 THEN
            ROUND(100.0 * seq_scan / (seq_scan + idx_scan), 2)
        ELSE 0
    END AS seq_scan_pct
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC;

-- =====================================================
-- 3. OPTIMIZE INDEXES
-- =====================================================

-- Find duplicate indexes
WITH index_data AS (
    SELECT
        indrelid,
        indexrelid,
        indkey,
        indclass,
        indoption,
        pg_get_indexdef(indexrelid) AS indexdef
    FROM pg_index
)
SELECT
    a.indexdef AS duplicate_index,
    b.indexdef AS original_index
FROM index_data a
JOIN index_data b ON a.indrelid = b.indrelid
    AND a.indexrelid != b.indexrelid
    AND a.indkey = b.indkey
    AND a.indclass = b.indclass
    AND a.indoption = b.indoption;

-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelname NOT LIKE 'pg_toast%'
ORDER BY pg_relation_size(indexrelid) DESC;

-- =====================================================
-- 4. OPTIMIZE CRAWL_RESULTS TABLE
-- =====================================================

-- Create optimized indexes for common queries
CREATE INDEX IF NOT EXISTS idx_crawl_results_url_created
    ON crawl_results(url, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crawl_results_created_at
    ON crawl_results(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crawl_results_seo_score
    ON crawl_results(seo_score DESC)
    WHERE seo_score IS NOT NULL;

-- Partial index for active crawls
CREATE INDEX IF NOT EXISTS idx_crawl_results_active
    ON crawl_results(status, created_at DESC)
    WHERE status IN ('pending', 'processing');

-- =====================================================
-- 5. OPTIMIZE RAG_EMBEDDINGS TABLE
-- =====================================================

-- Vector similarity search optimization
CREATE INDEX IF NOT EXISTS idx_rag_embeddings_vector
    ON rag_embeddings
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Compound index for filtering + vector search
CREATE INDEX IF NOT EXISTS idx_rag_embeddings_url_chunk
    ON rag_embeddings(url, chunk_index);

-- =====================================================
-- 6. OPTIMIZE RLS POLICIES
-- =====================================================

-- Check RLS policy performance
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public';

-- Example: Optimized RLS policy using index
-- DROP POLICY IF EXISTS "efficient_read" ON crawl_results;
-- CREATE POLICY "efficient_read" ON crawl_results
--     FOR SELECT
--     USING (
--         user_id = auth.uid()
--         OR is_public = true
--     );

-- =====================================================
-- 7. TABLE MAINTENANCE
-- =====================================================

-- Check table bloat
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size,
    ROUND(100 * (pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) / pg_total_relation_size(schemaname||'.'||tablename)::numeric, 2) AS indexes_pct
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Vacuum and analyze tables
VACUUM ANALYZE crawl_results;
VACUUM ANALYZE rag_embeddings;
VACUUM ANALYZE competitor_data;
VACUUM ANALYZE webvitals_metrics;

-- =====================================================
-- 8. CONNECTION POOL MONITORING
-- =====================================================

-- Check current connections
SELECT
    datname,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY query_start DESC;

-- Connection pool stats
SELECT
    count(*) AS total_connections,
    count(*) FILTER (WHERE state = 'active') AS active,
    count(*) FILTER (WHERE state = 'idle') AS idle,
    count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction
FROM pg_stat_activity
WHERE datname = current_database();