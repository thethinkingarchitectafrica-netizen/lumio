-- ============================================
-- Supabase Project 1 (Vector Store)
-- ============================================

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- CHUNKS TABLE (VECTOR STORE)
-- ============================================
CREATE TABLE chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    embedding VECTOR(1024),

    -- Source metadata
    source_document TEXT NOT NULL,
    source_type TEXT NOT NULL CHECK (source_type IN ('ada', 'osha', 'nigeria_building_code', 'lagos_state', 'uk_approved_docs', 'community')),
    jurisdiction TEXT NOT NULL,

    -- Location metadata
    section_number TEXT,
    section_title TEXT,
    page_number INTEGER,
    chapter TEXT,

    -- Hierarchy metadata
    parent_chunk_id UUID REFERENCES chunks(id),
    hierarchy_level INTEGER DEFAULT 0,
    hierarchy_path TEXT[],

    -- Version metadata
    edition TEXT NOT NULL,
    effective_date DATE,
    status TEXT NOT NULL DEFAULT 'current' CHECK (status IN ('current', 'superseded', 'draft', 'archived')),
    superseded_by UUID REFERENCES chunks(id),
    next_review_date DATE,

    -- Content metadata
    topic_tags TEXT[],
    content_type TEXT DEFAULT 'text' CHECK (content_type IN ('text', 'table', 'list', 'definition', 'requirement', 'exception')),

    -- Cross-references
    cross_references JSONB DEFAULT '[]'::JSONB,
    related_chunks UUID[],

    -- Deduplication
    content_hash TEXT NOT NULL UNIQUE,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Search support
    search_vector TSVECTOR
);

CREATE INDEX idx_chunks_embedding ON chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_chunks_source_type ON chunks(source_type);
CREATE INDEX idx_chunks_jurisdiction ON chunks(jurisdiction);
CREATE INDEX idx_chunks_status ON chunks(status);
CREATE INDEX idx_chunks_content_hash ON chunks(content_hash);
CREATE INDEX idx_chunks_search_vector ON chunks USING GIN(search_vector);
CREATE INDEX idx_chunks_topic_tags ON chunks USING GIN(topic_tags);

CREATE OR REPLACE FUNCTION update_chunks_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english', COALESCE(NEW.content, '') || ' ' || COALESCE(NEW.section_title, ''));
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER chunks_search_vector_update
    BEFORE INSERT OR UPDATE ON chunks
    FOR EACH ROW
    EXECUTE FUNCTION update_chunks_search_vector();

-- ============================================
-- Supabase Project 2 (User Database)
-- ============================================

-- ============================================
-- LUMIO GLOBAL MEMORY
-- ============================================
CREATE TABLE lumio_global_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    memory_key TEXT NOT NULL,
    memory_value TEXT NOT NULL,
    memory_embedding VECTOR(1024),

    category TEXT NOT NULL CHECK (category IN ('design_preference', 'technical_preference', 'location', 'practice_info', 'project', 'client')),
    subcategory TEXT,

    relevance_score FLOAT DEFAULT 1.0,
    access_count INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    expiry_warning_sent BOOLEAN DEFAULT FALSE,

    supersedes_memory_id UUID REFERENCES lumio_global_memory(id),
    is_active BOOLEAN DEFAULT TRUE,

    source_type TEXT DEFAULT 'user_explicit' CHECK (source_type IN ('user_explicit', 'inferred', 'conversation')),
    source_conversation_id UUID,

    UNIQUE(user_id, memory_key)
);

CREATE INDEX idx_global_memory_user ON lumio_global_memory(user_id);
CREATE INDEX idx_global_memory_category ON lumio_global_memory(category);
CREATE INDEX idx_global_memory_active ON lumio_global_memory(is_active);
CREATE INDEX idx_global_memory_embedding ON lumio_global_memory USING ivfflat (memory_embedding vector_cosine_ops) WITH (lists = 50);

-- ============================================
-- LUMIO CHAT HISTORY
-- ============================================
CREATE TABLE lumio_chat_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL,

    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    content_embedding VECTOR(1024),

    message_index INTEGER NOT NULL,
    tokens_used INTEGER,

    is_summarized BOOLEAN DEFAULT FALSE,
    summary_text TEXT,
    original_message_ids UUID[],

    confidence_score FLOAT,
    sources_used JSONB,
    cache_hit BOOLEAN DEFAULT FALSE,
    response_time_ms INTEGER,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(session_id, message_index)
);

CREATE INDEX idx_chat_history_user ON lumio_chat_history(user_id);
CREATE INDEX idx_chat_history_session ON lumio_chat_history(session_id);
CREATE INDEX idx_chat_history_created ON lumio_chat_history(created_at);
CREATE INDEX idx_chat_history_embedding ON lumio_chat_history USING ivfflat (content_embedding vector_cosine_ops) WITH (lists = 50);

-- ============================================
-- LUMIO CACHE
-- ============================================
CREATE TABLE lumio_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    query_text TEXT NOT NULL,
    query_embedding VECTOR(1024) NOT NULL,
    query_hash TEXT NOT NULL UNIQUE,

    response_text TEXT NOT NULL,
    response_sources JSONB NOT NULL,
    confidence_score FLOAT NOT NULL,

    jurisdiction_context TEXT,
    user_context_hash TEXT,

    hit_count INTEGER DEFAULT 0,
    last_hit_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,

    is_valid BOOLEAN DEFAULT TRUE,
    invalidated_reason TEXT
);

CREATE INDEX idx_cache_embedding ON lumio_cache USING ivfflat (query_embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_cache_hash ON lumio_cache(query_hash);
CREATE INDEX idx_cache_expires ON lumio_cache(expires_at);
CREATE INDEX idx_cache_valid ON lumio_cache(is_valid);

-- ============================================
-- LUMIO ACCESS LOG
-- ============================================
CREATE TABLE lumio_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    session_id UUID,
    ip_address INET,
    user_agent TEXT,

    action_type TEXT NOT NULL CHECK (action_type IN ('query', 'memory_read', 'memory_write', 'memory_delete', 'login', 'logout', 'signup', 'cache_hit', 'rate_limit', 'error')),
    action_detail TEXT,

    resource_type TEXT,
    resource_id UUID,

    success BOOLEAN NOT NULL,
    error_message TEXT,
    response_time_ms INTEGER,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_access_log_user ON lumio_access_log(user_id);
CREATE INDEX idx_access_log_action ON lumio_access_log(action_type);
CREATE INDEX idx_access_log_created ON lumio_access_log(created_at);
CREATE INDEX idx_access_log_success ON lumio_access_log(success);

-- ============================================
-- VERSION TRACKING
-- ============================================
CREATE TABLE version_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_type TEXT NOT NULL,
    jurisdiction TEXT NOT NULL,
    document_name TEXT NOT NULL,

    current_edition TEXT NOT NULL,
    effective_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'current' CHECK (status IN ('current', 'superseded', 'draft', 'pending')),

    publisher_url TEXT,
    last_checked_at TIMESTAMPTZ,
    next_check_at TIMESTAMPTZ,

    detected_new_edition BOOLEAN DEFAULT FALSE,
    new_edition_details TEXT,
    alert_sent BOOLEAN DEFAULT FALSE,

    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(source_type, jurisdiction, document_name)
);

CREATE INDEX idx_version_tracking_source ON version_tracking(source_type);
CREATE INDEX idx_version_tracking_status ON version_tracking(status);
CREATE INDEX idx_version_tracking_next_check ON version_tracking(next_check_at);

-- ============================================
-- KNOWLEDGE GAP LOG
-- ============================================
CREATE TABLE knowledge_gap_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    query_text TEXT NOT NULL,
    query_embedding VECTOR(1024),

    detected_jurisdiction TEXT,
    detected_topic TEXT,
    gap_type TEXT NOT NULL CHECK (gap_type IN ('jurisdiction_not_covered', 'topic_not_covered', 'insufficient_confidence', 'outdated_source', 'conflicting_sources')),

    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    session_id UUID,

    fallback_response TEXT,
    referral_given TEXT,

    similarity_score FLOAT,
    best_match_chunk_id UUID,

    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gap_log_jurisdiction ON knowledge_gap_log(detected_jurisdiction);
CREATE INDEX idx_gap_log_topic ON knowledge_gap_log(detected_topic);
CREATE INDEX idx_gap_log_type ON knowledge_gap_log(gap_type);
CREATE INDEX idx_gap_log_resolved ON knowledge_gap_log(is_resolved);
CREATE INDEX idx_gap_log_created ON knowledge_gap_log(created_at);

-- ============================================
-- COMMUNITY SUBMISSIONS
-- ============================================
CREATE TABLE community_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    contributor_verified BOOLEAN DEFAULT FALSE,

    submission_type TEXT NOT NULL CHECK (submission_type IN ('correction', 'addition', 'update', 'clarification')),
    title TEXT NOT NULL,
    content TEXT NOT NULL,

    related_jurisdiction TEXT NOT NULL,
    related_topic TEXT NOT NULL,
    related_chunk_ids UUID[],

    source_citation TEXT,
    source_url TEXT,
    attachments JSONB,

    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected', 'needs_revision')),
    reviewer_id UUID REFERENCES auth.users(id),
    review_notes TEXT,
    reviewed_at TIMESTAMPTZ,

    resulting_chunk_id UUID,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_submissions_user ON community_submissions(user_id);
CREATE INDEX idx_submissions_status ON community_submissions(status);
CREATE INDEX idx_submissions_jurisdiction ON community_submissions(related_jurisdiction);
CREATE INDEX idx_submissions_created ON community_submissions(created_at);

-- ============================================
-- MEM0 FALLBACK
-- ============================================
CREATE TABLE mem0_fallback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    memory_id TEXT NOT NULL,
    memory_data JSONB NOT NULL,
    memory_embedding VECTOR(1024),

    synced_to_mem0 BOOLEAN DEFAULT FALSE,
    sync_attempted_at TIMESTAMPTZ,
    sync_error TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, memory_id)
);

CREATE INDEX idx_fallback_user ON mem0_fallback(user_id);
CREATE INDEX idx_fallback_synced ON mem0_fallback(synced_to_mem0);
