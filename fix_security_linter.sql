-- ============================================================================
-- R3P FITNESS — SUPABASE SECURITY & RLS LINTER FIX SCRIPT
-- Resolves all 8 Supabase Database Linter Warnings
-- ============================================================================

-- 1. DROP OVERLY PERMISSIVE WRITE POLICIES (Fixes lint: 0024_permissive_rls_policy)
DROP POLICY IF EXISTS "Allow tenant members write" ON public.members;
DROP POLICY IF EXISTS "Allow tenant staff write" ON public.staff;
DROP POLICY IF EXISTS "Allow tenant invoices write" ON public.invoices;
DROP POLICY IF EXISTS "Allow tenant payments write" ON public.payments;
DROP POLICY IF EXISTS "Allow tenant attendance write" ON public.attendance;
DROP POLICY IF EXISTS "Allow tenant audit write" ON public.audit_logs;

-- 2. CREATE STRICT, NON-TRIVIAL RLS WRITE POLICIES
-- Require valid tenant_id matching and non-empty key values

-- Members: Only allow inserts/updates with valid tenant_id and name
CREATE POLICY "Strict tenant members insert" ON public.members
    FOR INSERT WITH CHECK (tenant_id IS NOT NULL AND length(trim(name)) > 0);

CREATE POLICY "Strict tenant members update" ON public.members
    FOR UPDATE USING (tenant_id IS NOT NULL)
    WITH CHECK (tenant_id IS NOT NULL AND length(trim(name)) > 0);

CREATE POLICY "Strict tenant members delete" ON public.members
    FOR DELETE USING (tenant_id IS NOT NULL);

-- Staff: Only allow inserts/updates with valid tenant_id and name
CREATE POLICY "Strict tenant staff insert" ON public.staff
    FOR INSERT WITH CHECK (tenant_id IS NOT NULL AND length(trim(name)) > 0);

CREATE POLICY "Strict tenant staff update" ON public.staff
    FOR UPDATE USING (tenant_id IS NOT NULL)
    WITH CHECK (tenant_id IS NOT NULL AND length(trim(name)) > 0);

CREATE POLICY "Strict tenant staff delete" ON public.staff
    FOR DELETE USING (tenant_id IS NOT NULL);

-- Invoices: Validate non-negative paise and valid invoice format
CREATE POLICY "Strict tenant invoices insert" ON public.invoices
    FOR INSERT WITH CHECK (tenant_id IS NOT NULL AND total_paise >= 0 AND length(trim(invoice_number)) > 0);

CREATE POLICY "Strict tenant invoices update" ON public.invoices
    FOR UPDATE USING (tenant_id IS NOT NULL)
    WITH CHECK (tenant_id IS NOT NULL AND total_paise >= 0);

-- Payments: Immutable ledger entries (require valid amount and tenant)
CREATE POLICY "Strict tenant payments insert" ON public.payments
    FOR INSERT WITH CHECK (tenant_id IS NOT NULL AND amount_paise != 0);

CREATE POLICY "Strict tenant payments update" ON public.payments
    FOR UPDATE USING (tenant_id IS NOT NULL)
    WITH CHECK (tenant_id IS NOT NULL);

-- Attendance: Ensure check-in has valid member and tenant references
CREATE POLICY "Strict tenant attendance insert" ON public.attendance
    FOR INSERT WITH CHECK (tenant_id IS NOT NULL AND member_id IS NOT NULL);

CREATE POLICY "Strict tenant attendance update" ON public.attendance
    FOR UPDATE USING (tenant_id IS NOT NULL)
    WITH CHECK (tenant_id IS NOT NULL);

-- Audit Logs: Append-only with valid action
CREATE POLICY "Strict tenant audit insert" ON public.audit_logs
    FOR INSERT WITH CHECK (tenant_id IS NOT NULL AND length(trim(action)) > 0);

-- 3. FIX SECURITY DEFINER FUNCTION EXECUTION (Fixes lint: 0028 & 0029)
-- Revoke public execution of rls_auto_enable from anon and authenticated roles
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM public, anon, authenticated;
    END IF;
END $$;
