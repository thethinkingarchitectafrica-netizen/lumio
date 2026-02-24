-- ============================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================

-- Supabase Project 1 (Vector Store)
ALTER TABLE chunks ENABLE ROW LEVEL SECURITY;

-- Supabase Project 2 (User Database)
ALTER TABLE lumio_global_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE lumio_chat_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE lumio_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE lumio_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE version_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_gap_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mem0_fallback ENABLE ROW LEVEL SECURITY;
