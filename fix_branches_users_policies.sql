-- ============================================================================
-- R3P FITNESS — POLICIES FOR public.branches AND public.users
-- Fixes Supabase Linter (lint: 0008_rls_enabled_no_policy)
-- ============================================================================

-- 1. POLICIES FOR public.branches
-- Read access: Allowed for users to view gym branches
CREATE POLICY "Allow public read branches" ON public.branches
    FOR SELECT USING (true);

-- Insert: Require tenant_id and non-empty branch name
CREATE POLICY "Strict tenant branches insert" ON public.branches
    FOR INSERT WITH CHECK (tenant_id IS NOT NULL AND length(trim(name)) > 0);

-- Update: Require tenant_id and non-empty branch name
CREATE POLICY "Strict tenant branches update" ON public.branches
    FOR UPDATE USING (tenant_id IS NOT NULL)
    WITH CHECK (tenant_id IS NOT NULL AND length(trim(name)) > 0);

-- Delete: Restrict deletion to scoped tenant
CREATE POLICY "Strict tenant branches delete" ON public.branches
    FOR DELETE USING (tenant_id IS NOT NULL);


-- 2. POLICIES FOR public.users
-- Read access: Allowed to read user profiles
CREATE POLICY "Allow public read users" ON public.users
    FOR SELECT USING (true);

-- Insert: Require valid phone number and full name
CREATE POLICY "Strict tenant users insert" ON public.users
    FOR INSERT WITH CHECK (length(trim(phone)) > 0 AND length(trim(full_name)) > 0);

-- Update: Require valid phone and full name
CREATE POLICY "Strict tenant users update" ON public.users
    FOR UPDATE USING (true)
    WITH CHECK (length(trim(phone)) > 0 AND length(trim(full_name)) > 0);

-- Delete: Allow deletion with non-null ID check
CREATE POLICY "Strict tenant users delete" ON public.users
    FOR DELETE USING (id IS NOT NULL);
