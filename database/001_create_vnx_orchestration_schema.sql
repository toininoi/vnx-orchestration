-- ============================================================================
-- VNX Orchestration System Database Schema
-- Version: 001
-- Description: Core database for VNX terminal orchestration and report tracking
-- Author: T-MANAGER
-- Date: 2025-09-24
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create VNX orchestration schema
CREATE SCHEMA IF NOT EXISTS vnx_system;

-- ============================================================================
-- VNX Terminal Reports Table
-- ============================================================================
CREATE TABLE vnx_system.terminal_reports (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,

    -- Report identification
    terminal TEXT NOT NULL CHECK (terminal IN ('T0', 'T1', 'T2', 'T3')),
    file_path TEXT NOT NULL UNIQUE,
    file_name TEXT NOT NULL,
    report_type TEXT NOT NULL, -- IMPL, TEST, ANALYSIS, VALIDATION, etc.
    title TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Content metadata
    status TEXT CHECK (status IN ('success', 'blocked', 'in_progress', 'pending')),
    gate TEXT CHECK (gate IN ('planning', 'implementation', 'review', 'testing', 'validation')),
    priority TEXT DEFAULT 'P2', -- P0, P1, P2, P3

    -- Tagging system
    issue_tags TEXT[] DEFAULT '{}', -- #uuid-issue, #rag-chunks, #storage-failure, etc.
    component_tags TEXT[] DEFAULT '{}', -- #crawler, #storage, #webvitals, etc.
    solution_tags TEXT[] DEFAULT '{}', -- #performance-fix, #architecture-change, etc.

    -- Content analysis
    content_summary TEXT,
    key_findings TEXT[],
    related_files TEXT[],

    -- Performance metrics
    execution_time_ms INTEGER,
    memory_usage_mb REAL,
    success_rate REAL,

    -- Correlation fields
    batch_id UUID, -- Link to project batches
    related_reports UUID[], -- Array of related report IDs
    recurring_issue_id UUID, -- Link to recurring issue patterns

    -- Full content for search
    full_content JSONB,

    CONSTRAINT terminal_reports_terminal_file_unique UNIQUE (terminal, file_name)
);

-- ============================================================================
-- VNX Recurring Issues Table
-- ============================================================================
CREATE TABLE vnx_system.recurring_issues (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,

    -- Issue identification
    issue_name TEXT NOT NULL UNIQUE,
    primary_tags TEXT[] NOT NULL,
    description TEXT,

    -- Pattern tracking
    first_occurrence TIMESTAMP WITH TIME ZONE,
    last_occurrence TIMESTAMP WITH TIME ZONE,
    occurrence_count INTEGER DEFAULT 0,

    -- Resolution tracking
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'monitoring')),
    resolution_pattern TEXT,
    prevention_notes TEXT,

    -- Correlation data
    related_components TEXT[],
    common_solutions TEXT[],

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- VNX Dispatches Table (track dispatch history)
-- ============================================================================
CREATE TABLE vnx_system.dispatches (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,

    dispatch_id TEXT NOT NULL UNIQUE, -- e.g., "20250924-201755-7ea0dd31-C"
    target_terminal TEXT NOT NULL CHECK (target_terminal IN ('T1', 'T2', 'T3')),
    role TEXT NOT NULL, -- architect-opus, developer, etc.
    priority TEXT NOT NULL,
    cognition TEXT CHECK (cognition IN ('normal', 'deep')),

    -- Timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Status tracking
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),

    -- Content
    instruction TEXT,
    context_files TEXT[],

    -- Results
    result_report_id UUID REFERENCES vnx_system.terminal_reports(id),

    -- Performance
    processing_time_ms INTEGER,

    CONSTRAINT dispatches_unique_id UNIQUE (dispatch_id)
);

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

-- Terminal reports indexes
CREATE INDEX idx_terminal_reports_issue_tags ON vnx_system.terminal_reports USING GIN (issue_tags);
CREATE INDEX idx_terminal_reports_component_tags ON vnx_system.terminal_reports USING GIN (component_tags);
CREATE INDEX idx_terminal_reports_solution_tags ON vnx_system.terminal_reports USING GIN (solution_tags);
CREATE INDEX idx_terminal_reports_terminal_created ON vnx_system.terminal_reports (terminal, created_at DESC);
CREATE INDEX idx_terminal_reports_status_gate ON vnx_system.terminal_reports (status, gate);

-- Recurring issues indexes
CREATE INDEX idx_recurring_issues_primary_tags ON vnx_system.recurring_issues USING GIN (primary_tags);
CREATE INDEX idx_recurring_issues_status ON vnx_system.recurring_issues (status);

-- Dispatches indexes
CREATE INDEX idx_dispatches_terminal_status ON vnx_system.dispatches (target_terminal, status);
CREATE INDEX idx_dispatches_created_at ON vnx_system.dispatches (created_at DESC);
CREATE INDEX idx_dispatches_role ON vnx_system.dispatches (role);

-- ============================================================================
-- VNX System Functions
-- ============================================================================

-- Function to search reports by tags
CREATE OR REPLACE FUNCTION vnx_system.search_reports_by_tags(
    p_issue_tags TEXT[] DEFAULT NULL,
    p_component_tags TEXT[] DEFAULT NULL,
    p_solution_tags TEXT[] DEFAULT NULL,
    p_terminal TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    terminal TEXT,
    title TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    issue_tags TEXT[],
    component_tags TEXT[],
    solution_tags TEXT[],
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.terminal,
        r.title,
        r.created_at,
        r.issue_tags,
        r.component_tags,
        r.solution_tags,
        r.status
    FROM vnx_system.terminal_reports r
    WHERE
        (p_issue_tags IS NULL OR r.issue_tags && p_issue_tags)
        AND (p_component_tags IS NULL OR r.component_tags && p_component_tags)
        AND (p_solution_tags IS NULL OR r.solution_tags && p_solution_tags)
        AND (p_terminal IS NULL OR r.terminal = p_terminal)
    ORDER BY r.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get tag statistics
CREATE OR REPLACE FUNCTION vnx_system.tag_statistics()
RETURNS TABLE (
    tag_type TEXT,
    tag_name TEXT,
    usage_count BIGINT,
    terminals TEXT[]
) AS $$
BEGIN
    -- Issue tags statistics
    RETURN QUERY
    SELECT
        'issue'::TEXT as tag_type,
        unnest(issue_tags) as tag_name,
        COUNT(*)::BIGINT as usage_count,
        ARRAY_AGG(DISTINCT terminal ORDER BY terminal) as terminals
    FROM vnx_system.terminal_reports
    WHERE array_length(issue_tags, 1) > 0
    GROUP BY unnest(issue_tags);

    -- Component tags statistics
    RETURN QUERY
    SELECT
        'component'::TEXT as tag_type,
        unnest(component_tags) as tag_name,
        COUNT(*)::BIGINT as usage_count,
        ARRAY_AGG(DISTINCT terminal ORDER BY terminal) as terminals
    FROM vnx_system.terminal_reports
    WHERE array_length(component_tags, 1) > 0
    GROUP BY unnest(component_tags);

    -- Solution tags statistics
    RETURN QUERY
    SELECT
        'solution'::TEXT as tag_type,
        unnest(solution_tags) as tag_name,
        COUNT(*)::BIGINT as usage_count,
        ARRAY_AGG(DISTINCT terminal ORDER BY terminal) as terminals
    FROM vnx_system.terminal_reports
    WHERE array_length(solution_tags, 1) > 0
    GROUP BY unnest(solution_tags);
END;
$$ LANGUAGE plpgsql;

-- Function to track recurring issues
CREATE OR REPLACE FUNCTION vnx_system.update_recurring_issues()
RETURNS TRIGGER AS $$
BEGIN
    -- Update occurrence count for any matching recurring issues
    UPDATE vnx_system.recurring_issues
    SET
        occurrence_count = occurrence_count + 1,
        last_occurrence = NEW.created_at,
        updated_at = CURRENT_TIMESTAMP
    WHERE
        primary_tags && NEW.issue_tags; -- Array overlap operator

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER terminal_reports_recurring_issues_trigger
    AFTER INSERT ON vnx_system.terminal_reports
    FOR EACH ROW
    EXECUTE FUNCTION vnx_system.update_recurring_issues();

-- ============================================================================
-- Initial Data - Seed known recurring issues
-- ============================================================================

INSERT INTO vnx_system.recurring_issues (
    issue_name,
    primary_tags,
    description,
    first_occurrence,
    occurrence_count
) VALUES
    (
        'uuid-conversion-errors',
        ARRAY['uuid-issue', 'storage'],
        'UUID type conversion issues - string vs UUID object mismatches',
        '2025-01-24 14:06:00Z',
        3
    ),
    (
        'rag-chunks-table-mismatch',
        ARRAY['rag-chunks', 'rag-pipeline', 'storage'],
        'RAG pipeline using wrong table (content_chunks vs rag_chunks)',
        '2025-09-24 13:40:00Z',
        2
    ),
    (
        'dispatcher-role-parsing',
        ARRAY['dispatcher', 'orchestration', 'template-compilation'],
        'Dispatcher V7 role parsing issues with spaces and compound names',
        '2025-09-24 20:07:00Z',
        4
    )
ON CONFLICT (issue_name) DO NOTHING;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON SCHEMA vnx_system IS 'VNX Orchestration System database schema for terminal coordination and report tracking';
COMMENT ON TABLE vnx_system.terminal_reports IS 'VNX Terminal Reports with tagging system for correlation';
COMMENT ON TABLE vnx_system.recurring_issues IS 'Tracks recurring issue patterns across VNX terminals';
COMMENT ON TABLE vnx_system.dispatches IS 'VNX dispatch history and performance tracking';