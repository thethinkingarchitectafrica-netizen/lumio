-- ============================================
-- RLS Policies
-- ============================================

-- Chunks table: restricted to service_role
CREATE POLICY chunks_service_role_access
    ON chunks
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- Lumio global memory: service_role or owning user
CREATE POLICY memory_owner_access
    ON lumio_global_memory
    FOR ALL
    USING (auth.role() = 'service_role' OR auth.uid() = user_id)
    WITH CHECK (auth.role() = 'service_role' OR auth.uid() = user_id);

-- Chat history: service_role or owning user
CREATE POLICY chat_history_owner_access
    ON lumio_chat_history
    FOR ALL
    USING (auth.role() = 'service_role' OR auth.uid() = user_id)
    WITH CHECK (auth.role() = 'service_role' OR auth.uid() = user_id);

-- Cache: service_role only
CREATE POLICY cache_service_access
    ON lumio_cache
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- Access log: service_role only
CREATE POLICY access_log_service_access
    ON lumio_access_log
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- Version tracking: service_role only
CREATE POLICY version_tracking_service_access
    ON version_tracking
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- Knowledge gap log: service_role only
CREATE POLICY knowledge_gap_service_access
    ON knowledge_gap_log
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- Community submissions: owners manage their rows, service role manages workflow
CREATE POLICY submissions_owner_read
    ON community_submissions
    FOR SELECT
    USING (auth.role() = 'service_role' OR auth.uid() = user_id);

CREATE POLICY submissions_owner_insert
    ON community_submissions
    FOR INSERT
    WITH CHECK (auth.role() = 'service_role' OR auth.uid() = user_id);

CREATE POLICY submissions_owner_update
    ON community_submissions
    FOR UPDATE
    USING (auth.role() = 'service_role' OR auth.uid() = user_id)
    WITH CHECK (auth.role() = 'service_role' OR auth.uid() = user_id);

CREATE POLICY submissions_service_access
    ON community_submissions
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- Mem0 fallback: service_role or owning user
CREATE POLICY mem0_owner_access
    ON mem0_fallback
    FOR ALL
    USING (auth.role() = 'service_role' OR auth.uid() = user_id)
    WITH CHECK (auth.role() = 'service_role' OR auth.uid() = user_id);
