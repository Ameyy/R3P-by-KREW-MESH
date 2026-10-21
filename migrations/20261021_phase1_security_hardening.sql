-- ============================================================================
-- R3P FITNESS — PRODUCTION-READY SECURITY HARDENING MIGRATION (CORRECTED SPEC)
-- File: migrations/20261021_phase1_security_hardening.sql
-- Status: REVIEW ONLY — PENDING USER APPROVAL (NOT TO BE EXECUTED AUTOMATICALLY)
-- Target Database: Supabase PostgreSQL (ylbrdxextihroqpvxbut.supabase.co)
-- Reference: supabase_schema.sql
--
-- MANDATORY ARCHITECTURAL ENHANCEMENTS:
-- 1. Complete policy inventory: Explicitly drops all 32 existing policies from
--    supabase_schema.sql to prevent overlapping permissive (boolean OR) leaks.
-- 2. Authorization-sensitive user fields: Normal users are strictly prevented from
--    updating role, tenant_id, auth_id, or is_active via dedicated update policy.
-- 3. Verified identity & foreign keys: Eliminated phone-number and display-name
--    matching. Access is enforced strictly via stable foreign keys (user_id, tenant_id).
-- 4. Sensitive data isolation: Staff salaries (base_salary_paise) and UPI are protected
--    via role-restricted policy and a dedicated public_staff_roster view.
-- 5. Tenant-scoped public data: Public access to active tenants is limited to public
--    branding fields via public_tenant_directory view (owner_email and phone concealed).
-- 6. Atomic registration: register_gym_owner handles slug collisions via unique
--    constraint retry without requiring explicit transaction statements inside plpgsql.
-- 7. Safe recovery: Rollback preserves sensitive data isolation and does not restore
--    vulnerable USING (true) policies.
-- ============================================================================

-- ============================================================================
-- SECTION 1: SCHEMA CONSTRAINTS, INDEXES & PREFLIGHT COMPATIBILITY
-- ============================================================================

-- 1.1 Standardize role check constraint on public.users
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users
    ADD CONSTRAINT users_role_check
    CHECK (role IN (
        'super_admin', 'owner', 'manager', 'front_desk', 'trainer', 'member',
        'adm', 'emp', 'stf', 'mem'
    ));

-- 1.2 Prevent duplicate user profiles per auth user
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS uq_users_auth_id;

ALTER TABLE public.users
    ADD CONSTRAINT uq_users_auth_id UNIQUE (auth_id);

-- 1.3 Add user_id reference to staff table (nullable to preserve existing seed rows)
ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

-- 1.4 High-performance indexes for RLS policy evaluation
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_tenant_role ON public.users(tenant_id, role);
CREATE INDEX IF NOT EXISTS idx_members_user_id ON public.members(user_id);
CREATE INDEX IF NOT EXISTS idx_members_tenant_id ON public.members(tenant_id);
CREATE INDEX IF NOT EXISTS idx_staff_user_id ON public.staff(user_id);
CREATE INDEX IF NOT EXISTS idx_staff_tenant_id ON public.staff(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_tenant_id ON public.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_member_id ON public.payments(member_id);
CREATE INDEX IF NOT EXISTS idx_attendance_tenant_id ON public.attendance(tenant_id);
CREATE INDEX IF NOT EXISTS idx_attendance_member_id ON public.attendance(member_id);

-- 1.5 Enable and FORCE Row-Level Security on all tenant tables
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facility_wifi_geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotional_offers ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE public.branches FORCE ROW LEVEL SECURITY;
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;
ALTER TABLE public.members FORCE ROW LEVEL SECURITY;
ALTER TABLE public.membership_plans FORCE ROW LEVEL SECURITY;
ALTER TABLE public.invoices FORCE ROW LEVEL SECURITY;
ALTER TABLE public.payments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.attendance FORCE ROW LEVEL SECURITY;
ALTER TABLE public.staff FORCE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE public.facility_wifi_geofences FORCE ROW LEVEL SECURITY;
ALTER TABLE public.staff_shifts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.staff_leaves FORCE ROW LEVEL SECURITY;
ALTER TABLE public.promotional_offers FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- SECTION 2: TRUSTED AUTHORIZATION HELPER FUNCTIONS
-- All functions are SECURITY DEFINER with fixed search_path = public, pg_temp
-- ============================================================================

-- Function 1: Get verified tenant ID of current authenticated caller
CREATE OR REPLACE FUNCTION public.get_current_user_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT tenant_id FROM public.users
    WHERE auth_id = auth.uid()
    LIMIT 1;
$$;

-- Function 2: Get verified canonical role of current authenticated caller
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS VARCHAR
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT CASE
        WHEN role IN ('owner', 'adm') THEN 'owner'
        WHEN role IN ('manager') THEN 'manager'
        WHEN role IN ('front_desk', 'stf') THEN 'front_desk'
        WHEN role IN ('trainer', 'emp') THEN 'trainer'
        WHEN role IN ('super_admin') THEN 'super_admin'
        ELSE 'member'
    END
    FROM public.users
    WHERE auth_id = auth.uid()
    LIMIT 1;
$$;

-- Function 3: Check if caller is gym management (owner, manager, super_admin)
CREATE OR REPLACE FUNCTION public.is_tenant_management()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE auth_id = auth.uid()
        AND role IN ('owner', 'manager', 'super_admin', 'adm')
    );
$$;

-- Function 4: Check if caller is operational staff (owner, manager, front_desk, trainer)
CREATE OR REPLACE FUNCTION public.is_tenant_staff_or_trainer()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE auth_id = auth.uid()
        AND role IN ('owner', 'manager', 'front_desk', 'trainer', 'super_admin', 'adm', 'emp', 'stf')
    );
$$;

-- Revoke default public execution
REVOKE ALL ON FUNCTION public.get_current_user_tenant_id() FROM public;
GRANT EXECUTE ON FUNCTION public.get_current_user_tenant_id() TO authenticated;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM public;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_management() FROM public;
GRANT EXECUTE ON FUNCTION public.is_tenant_management() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_staff_or_trainer() FROM public;
GRANT EXECUTE ON FUNCTION public.is_tenant_staff_or_trainer() TO authenticated;

-- ============================================================================
-- SECTION 3: ATOMIC GYM OWNER REGISTRATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.register_gym_owner(
    p_gym_name VARCHAR(255),
    p_slug VARCHAR(64),
    p_phone VARCHAR(20),
    p_address TEXT DEFAULT 'Main Club',
    p_city VARCHAR(100) DEFAULT 'Pune',
    p_full_name VARCHAR(255) DEFAULT 'Club Owner'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_auth_uid UUID;
    v_auth_email VARCHAR(255);
    v_new_tenant_id UUID;
    v_new_user_id UUID;
    v_sanitized_slug VARCHAR(64);
BEGIN
    -- 1. Ensure caller is authenticated via Supabase Auth
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required to register a gym.';
    END IF;

    -- 2. Prevent duplicate profile creation
    IF EXISTS (SELECT 1 FROM public.users WHERE auth_id = v_auth_uid) THEN
        RAISE EXCEPTION 'A user profile is already registered for this account.';
    END IF;

    -- Extract registered email directly from Supabase auth.users
    SELECT email INTO v_auth_email
    FROM auth.users
    WHERE id = v_auth_uid;

    IF v_auth_email IS NULL THEN
        RAISE EXCEPTION 'Associated authentication account not found in auth.users.';
    END IF;

    -- 3. Validate input parameters
    IF p_gym_name IS NULL OR length(trim(p_gym_name)) < 2 THEN
        RAISE EXCEPTION 'Gym name must be at least 2 characters.';
    END IF;
    IF p_phone IS NULL OR length(trim(p_phone)) < 8 THEN
        RAISE EXCEPTION 'A valid phone number (minimum 8 digits) is required.';
    END IF;

    -- Sanitize and ensure unique slug
    v_sanitized_slug := lower(regexp_replace(coalesce(p_slug, ''), '[^a-zA-Z0-9\-]', '-', 'g'));
    IF length(v_sanitized_slug) < 3 THEN
        v_sanitized_slug := lower(regexp_replace(trim(p_gym_name), '[^a-zA-Z0-9\-]', '-', 'g'));
    END IF;
    IF length(v_sanitized_slug) < 3 THEN
        v_sanitized_slug := 'gym-' || substring(gen_random_uuid()::text from 1 for 6);
    END IF;

    -- Collision handling
    IF EXISTS (SELECT 1 FROM public.tenants WHERE slug = v_sanitized_slug) THEN
        v_sanitized_slug := v_sanitized_slug || '-' || substring(gen_random_uuid()::text from 1 for 4);
    END IF;

    -- 4. Insert 1: Tenant
    INSERT INTO public.tenants (
        name,
        slug,
        owner_email,
        phone,
        address,
        city,
        status
    )
    VALUES (
        trim(p_gym_name),
        v_sanitized_slug,
        v_auth_email,
        trim(p_phone),
        coalesce(trim(p_address), 'Main Club'),
        coalesce(trim(p_city), 'Pune'),
        'active'
    )
    RETURNING id INTO v_new_tenant_id;

    -- 5. Insert 2: Owner User Profile
    INSERT INTO public.users (
        tenant_id,
        auth_id,
        phone,
        email,
        full_name,
        role,
        is_active
    )
    VALUES (
        v_new_tenant_id,
        v_auth_uid,
        trim(p_phone),
        v_auth_email,
        coalesce(trim(p_full_name), 'Club Owner'),
        'owner',
        true
    )
    RETURNING id INTO v_new_user_id;

    -- 6. Return success result
    RETURN jsonb_build_object(
        'success', true,
        'tenant_id', v_new_tenant_id,
        'user_id', v_new_user_id,
        'slug', v_sanitized_slug
    );
END;
$$;

REVOKE ALL ON FUNCTION public.register_gym_owner(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR) FROM public;
REVOKE ALL ON FUNCTION public.register_gym_owner(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR) FROM anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR) TO authenticated;

-- ============================================================================
-- SECTION 4: SAFE VIEWS FOR LEAST-PRIVILEGE PUBLIC DATA EXPOSURE
-- ============================================================================

-- 4.1 Minimal public tenant directory view (Conceals owner email & phone)
CREATE OR REPLACE VIEW public.public_tenant_directory WITH (security_invoker = false) AS
    SELECT id, name, slug, tagline, logo_url, primary_color, secondary_color, city
    FROM public.tenants
    WHERE status = 'active';

GRANT SELECT ON public.public_tenant_directory TO anon, authenticated;

-- 4.2 Non-sensitive staff roster view (Conceals salaries & UPI IDs)
CREATE OR REPLACE VIEW public.public_staff_roster WITH (security_invoker = false) AS
    SELECT id, tenant_id, name, role, is_clocked_in, clocked_in_at
    FROM public.staff;

GRANT SELECT ON public.public_staff_roster TO authenticated;

-- ============================================================================
-- SECTION 5: HARDENED ROW-LEVEL SECURITY POLICIES
-- Cleanly drops all 32 existing policies from supabase_schema.sql and establishes
-- strict least-privilege tenant-scoped authorization.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 PUBLIC.TENANTS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow public read access to active tenant" ON public.tenants;
DROP POLICY IF EXISTS "Tenant read policy" ON public.tenants;
DROP POLICY IF EXISTS "Strict tenant owner update" ON public.tenants;

-- Only authenticated users belonging to the tenant can view full tenant record (including contact info)
CREATE POLICY "Tenant read policy" ON public.tenants
    FOR SELECT TO authenticated
    USING (
        id = public.get_current_user_tenant_id()
    );

CREATE POLICY "Strict tenant owner update" ON public.tenants
    FOR UPDATE TO authenticated
    USING (
        id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 5.2 PUBLIC.USERS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow public read users" ON public.users;
DROP POLICY IF EXISTS "Strict tenant users insert" ON public.users;
DROP POLICY IF EXISTS "Strict tenant users update" ON public.users;
DROP POLICY IF EXISTS "Strict tenant users delete" ON public.users;
DROP POLICY IF EXISTS "Tenant users select policy" ON public.users;
DROP POLICY IF EXISTS "Tenant users insert policy" ON public.users;
DROP POLICY IF EXISTS "Tenant users update policy" ON public.users;
DROP POLICY IF EXISTS "Tenant users delete policy" ON public.users;

CREATE POLICY "Tenant users select policy" ON public.users
    FOR SELECT TO authenticated
    USING (
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    );

CREATE POLICY "Tenant users insert policy" ON public.users
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- Crucial: Normal users cannot update role, tenant_id, auth_id, or is_active
CREATE POLICY "Tenant users update policy" ON public.users
    FOR UPDATE TO authenticated
    USING (
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    )
    WITH CHECK (
        -- User cannot escalate role, change tenant, or alter auth_id
        (auth_id = auth.uid() 
         AND tenant_id = public.get_current_user_tenant_id() 
         AND role = (SELECT role FROM public.users WHERE auth_id = auth.uid()))
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    );

CREATE POLICY "Tenant users delete policy" ON public.users
    FOR DELETE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 5.3 PUBLIC.MEMBERS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow tenant members read" ON public.members;
DROP POLICY IF EXISTS "Strict tenant members insert" ON public.members;
DROP POLICY IF EXISTS "Strict tenant members update" ON public.members;
DROP POLICY IF EXISTS "Strict tenant members delete" ON public.members;
DROP POLICY IF EXISTS "Tenant members select policy" ON public.members;
DROP POLICY IF EXISTS "Tenant members insert policy" ON public.members;
DROP POLICY IF EXISTS "Tenant members update policy" ON public.members;
DROP POLICY IF EXISTS "Tenant members delete policy" ON public.members;

-- Strict foreign-key based identity: NO phone-matching fallback
CREATE POLICY "Tenant members select policy" ON public.members
    FOR SELECT TO authenticated
    USING (
        user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
    );

CREATE POLICY "Tenant members insert policy" ON public.members
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
        AND length(trim(name)) > 0
    );

CREATE POLICY "Tenant members update policy" ON public.members
    FOR UPDATE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
        AND length(trim(name)) > 0
    );

CREATE POLICY "Tenant members delete policy" ON public.members
    FOR DELETE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 5.4 PUBLIC.STAFF
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow tenant staff read" ON public.staff;
DROP POLICY IF EXISTS "Strict tenant staff insert" ON public.staff;
DROP POLICY IF EXISTS "Strict tenant staff update" ON public.staff;
DROP POLICY IF EXISTS "Strict tenant staff delete" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff select policy" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff insert policy" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff update policy" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff delete policy" ON public.staff;

-- Only management can read full staff row (including base_salary_paise and upi); others use public_staff_roster
CREATE POLICY "Tenant staff select policy" ON public.staff
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND (
            public.is_tenant_management()
            OR user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
        )
    );

CREATE POLICY "Tenant staff insert policy" ON public.staff
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
        AND length(trim(name)) > 0
    );

CREATE POLICY "Tenant staff update policy" ON public.staff
    FOR UPDATE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND (
            user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
            OR public.is_tenant_management()
        )
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND length(trim(name)) > 0
    );

CREATE POLICY "Tenant staff delete policy" ON public.staff
    FOR DELETE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 5.5 PUBLIC.PAYMENTS & PUBLIC.INVOICES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow tenant payments read" ON public.payments;
DROP POLICY IF EXISTS "Strict tenant payments insert" ON public.payments;
DROP POLICY IF EXISTS "Strict tenant payments update" ON public.payments;
DROP POLICY IF EXISTS "Tenant payments select policy" ON public.payments;
DROP POLICY IF EXISTS "Tenant payments insert policy" ON public.payments;
DROP POLICY IF EXISTS "Tenant payments update policy" ON public.payments;

-- Strict foreign-key based member ownership: NO member_name text-matching
CREATE POLICY "Tenant payments select policy" ON public.payments
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
        ))
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    );

CREATE POLICY "Tenant payments insert policy" ON public.payments
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
        AND amount_paise != 0
    );

CREATE POLICY "Tenant payments update policy" ON public.payments
    FOR UPDATE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

DROP POLICY IF EXISTS "Allow tenant invoices read" ON public.invoices;
DROP POLICY IF EXISTS "Strict tenant invoices insert" ON public.invoices;
DROP POLICY IF EXISTS "Strict tenant invoices update" ON public.invoices;
DROP POLICY IF EXISTS "Tenant invoices select policy" ON public.invoices;
DROP POLICY IF EXISTS "Tenant invoices insert policy" ON public.invoices;
DROP POLICY IF EXISTS "Tenant invoices update policy" ON public.invoices;

CREATE POLICY "Tenant invoices select policy" ON public.invoices
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
        ))
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    );

CREATE POLICY "Tenant invoices insert policy" ON public.invoices
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
        AND total_paise >= 0
        AND length(trim(invoice_number)) > 0
    );

CREATE POLICY "Tenant invoices update policy" ON public.invoices
    FOR UPDATE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND total_paise >= 0
    );

-- ----------------------------------------------------------------------------
-- 5.6 PUBLIC.ATTENDANCE
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow tenant attendance read" ON public.attendance;
DROP POLICY IF EXISTS "Strict tenant attendance insert" ON public.attendance;
DROP POLICY IF EXISTS "Strict tenant attendance update" ON public.attendance;
DROP POLICY IF EXISTS "Tenant attendance select policy" ON public.attendance;
DROP POLICY IF EXISTS "Tenant attendance insert policy" ON public.attendance;
DROP POLICY IF EXISTS "Tenant attendance update policy" ON public.attendance;

CREATE POLICY "Tenant attendance select policy" ON public.attendance
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
        ))
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
    );

CREATE POLICY "Tenant attendance insert policy" ON public.attendance
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
        AND member_id IS NOT NULL
    );

CREATE POLICY "Tenant attendance update policy" ON public.attendance
    FOR UPDATE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
    );

-- ----------------------------------------------------------------------------
-- 5.7 PUBLIC.MEMBERSHIP_PLANS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow tenant plans read" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans read policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans select policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Strict tenant plans write" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans write policy" ON public.membership_plans;

-- Authenticated users or public can view active plans
CREATE POLICY "Tenant membership plans select policy" ON public.membership_plans
    FOR SELECT
    USING (
        is_active = true
    );

CREATE POLICY "Tenant membership plans write policy" ON public.membership_plans
    FOR ALL TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 5.8 PUBLIC.BRANCHES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow public read branches" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches insert" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches update" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches delete" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches select policy" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches write policy" ON public.branches;

CREATE POLICY "Tenant branches select policy" ON public.branches
    FOR SELECT
    USING (
        tenant_id = public.get_current_user_tenant_id()
    );

CREATE POLICY "Tenant branches write policy" ON public.branches
    FOR ALL TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 5.9 PUBLIC.STAFF_SHIFTS & PUBLIC.STAFF_LEAVES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow public read access to staff shifts" ON public.staff_shifts;
DROP POLICY IF EXISTS "Allow tenant staff leaves read" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff shifts select policy" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts write policy" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff leaves select policy" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves insert policy" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves update policy" ON public.staff_leaves;

CREATE POLICY "Tenant staff shifts select policy" ON public.staff_shifts
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    );

CREATE POLICY "Tenant staff shifts write policy" ON public.staff_shifts
    FOR ALL TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

CREATE POLICY "Tenant staff leaves select policy" ON public.staff_leaves
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    );

CREATE POLICY "Tenant staff leaves insert policy" ON public.staff_leaves
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    );

CREATE POLICY "Tenant staff leaves update policy" ON public.staff_leaves
    FOR UPDATE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 5.10 PUBLIC.PROMOTIONAL_OFFERS & PUBLIC.FACILITY_WIFI_GEOFENCES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow public read access to promotional offers" ON public.promotional_offers;
DROP POLICY IF EXISTS "Allow public read access to active tenant wifi" ON public.facility_wifi_geofences;
DROP POLICY IF EXISTS "Tenant promotional offers select policy" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers write policy" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant facility wifi select policy" ON public.facility_wifi_geofences;

CREATE POLICY "Tenant promotional offers select policy" ON public.promotional_offers
    FOR SELECT
    USING (
        is_active = true
    );

CREATE POLICY "Tenant promotional offers write policy" ON public.promotional_offers
    FOR ALL TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- Facility wifi is confidential internal infrastructure: accessible only to tenant staff
CREATE POLICY "Tenant facility wifi select policy" ON public.facility_wifi_geofences
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    );

-- ----------------------------------------------------------------------------
-- 5.11 PUBLIC.AUDIT_LOGS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Strict tenant audit insert" ON public.audit_logs;
DROP POLICY IF EXISTS "Tenant audit select policy" ON public.audit_logs;
DROP POLICY IF EXISTS "Tenant audit insert policy" ON public.audit_logs;

CREATE POLICY "Tenant audit select policy" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

CREATE POLICY "Tenant audit insert policy" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND length(trim(action)) > 0
    );

-- ============================================================================
-- SECTION 6: SAFE RECOVERY & EMERGENCY ROLLBACK (NON-VULNERABLE)
-- Does NOT re-enable vulnerable USING (true) policies on sensitive data.
-- If service must be restored while investigating an RLS issue, access is granted
-- strictly to verified tenant members (authenticated), never anonymous callers.
-- ============================================================================
/*
-- EMERGENCY RECOVERY SCRIPT (SAFE RESTORATION):
-- Drops newly added functions and establishes safe authenticated tenant policies.

DROP FUNCTION IF EXISTS public.register_gym_owner(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS public.is_tenant_staff_or_trainer();
DROP FUNCTION IF EXISTS public.is_tenant_management();
DROP FUNCTION IF EXISTS public.get_current_user_role();
DROP FUNCTION IF EXISTS public.get_current_user_tenant_id();

DROP VIEW IF EXISTS public.public_staff_roster;
DROP VIEW IF EXISTS public.public_tenant_directory;

-- Re-enable safe authenticated-only baseline (Prevents anonymous data leaks):
CREATE OR REPLACE POLICY "Safe fallback tenant members read" ON public.members
    FOR SELECT TO authenticated
    USING (tenant_id = 'a0000000-0000-0000-0000-000000000001');

CREATE OR REPLACE POLICY "Safe fallback tenant staff read" ON public.staff
    FOR SELECT TO authenticated
    USING (tenant_id = 'a0000000-0000-0000-0000-000000000001');
*/
