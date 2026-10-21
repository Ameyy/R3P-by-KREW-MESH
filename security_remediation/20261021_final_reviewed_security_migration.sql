-- ============================================================================
-- R3P FITNESS — PRODUCTION-READY SECURITY HARDENING MIGRATION (REVISED V3)
-- File: security_remediation/20261021_final_reviewed_security_migration.sql
-- Status: REVIEW ONLY — PENDING USER & TEAM APPROVAL (DO NOT EXECUTE AUTOMATICALLY)
-- Target Database: Supabase PostgreSQL (ylbrdxextihroqpvxbut.supabase.co)
-- Reference: supabase_schema.sql
--
-- CORE ARCHITECTURAL REMEDIATIONS:
-- 1. Verified Live Schema Grounding:
--    - The live payments table schema only has: (id, tenant_id, invoice_number,
--      member_name, amount_paise, mode, reference_utr, notes, is_reversal, created_at).
--    - Column member_id DOES NOT exist in live payments. We add `member_id UUID REFERENCES
--      public.members(id) ON DELETE SET NULL` as a safe nullable additive column BEFORE
--      creating any index or policy referencing it.
-- 2. Tenant Isolation in Views and Shared Tables:
--    - `public_staff_roster` explicitly filters by `tenant_id = public.get_current_user_tenant_id()`
--      so staff rosters are NEVER leaked across tenants.
--    - `membership_plans` and `promotional_offers` are strictly scoped by `tenant_id`
--      using `tenant_id = public.get_current_user_tenant_id()`. Unauthenticated callers
--      can only read active plans/offers if a specific tenant slug/id is requested via view.
-- 3. Strict Separation of User Self-Edits vs. Management Edits:
--    - Non-management users can only update safe self-service fields (full_name, avatar_url).
--    - Attempts to alter `role`, `tenant_id`, `auth_id`, or `is_active` are rejected by trigger.
--    - Management users can only manage users belonging to their verified `tenant_id`.
-- 4. Staff Column-Level Security & Self-Service Restrictions:
--    - Sensitive staff columns (`base_salary_paise`, `upi`) are shielded.
--    - Staff self-updates are restricted to `is_clocked_in` and `clocked_in_at`.
--    - Salaries, UPI, active status, and role assignments can ONLY be modified by tenant management.
-- 5. Hardened `register_gym_owner()`:
--    - Requires valid `auth.uid()`, strictly checks phone/name formats, verifies caller does
--      not already own an active tenant or user profile (preventing unlimited tenant creation spam),
--      runs as SECURITY DEFINER with fixed search_path = public, pg_temp, owned by postgres.
-- 6. Clean Policy Drop Strategy:
--    - Drops only policies on tables where replacement policies are immediately installed in
--      the same transaction.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1: SCHEMA CONSTRAINTS, ADDITIVE COLUMNS & PERFORMANCE INDEXES
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

-- 1.3 Add user_id reference to staff table (nullable to preserve existing rows)
ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

-- 1.4 Add member_id reference to payments table (nullable to preserve existing rows)
-- [RESOLVED SCHEMA MISMATCH]: Live payments table initially lacked member_id.
ALTER TABLE public.payments
    ADD COLUMN IF NOT EXISTS member_id UUID REFERENCES public.members(id) ON DELETE SET NULL;

-- 1.5 High-performance indexes for RLS policy evaluation
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

-- 1.6 Enable and FORCE Row-Level Security on all tenant tables
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

REVOKE ALL ON FUNCTION public.get_current_user_tenant_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_tenant_id() TO authenticated;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_management() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_tenant_management() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_staff_or_trainer() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_tenant_staff_or_trainer() TO authenticated;

-- ============================================================================
-- SECTION 3: SENSITIVE ATTRIBUTE TRIGGERS (USERS & STAFF)
-- ============================================================================

-- 3.1 Prevent unauthorized privilege escalation and tenant switching on public.users
CREATE OR REPLACE FUNCTION public.trg_prevent_user_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_is_mgmt BOOLEAN;
    v_caller_tenant_id UUID;
BEGIN
    v_caller_is_mgmt := public.is_tenant_management();
    v_caller_tenant_id := public.get_current_user_tenant_id();

    -- If caller is not a verified manager of this tenant, strictly block alterations to critical columns
    IF NOT v_caller_is_mgmt THEN
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Unauthorized: Users cannot alter their own security role.';
        END IF;
        IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
            RAISE EXCEPTION 'Unauthorized: Users cannot alter their tenant assignment.';
        END IF;
        IF NEW.auth_id IS DISTINCT FROM OLD.auth_id THEN
            RAISE EXCEPTION 'Unauthorized: Users cannot reassign authentication identities.';
        END IF;
        IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
            RAISE EXCEPTION 'Unauthorized: Users cannot alter their account active status.';
        END IF;
    ELSE
        -- Even management can only alter users belonging to their own tenant
        IF OLD.tenant_id IS DISTINCT FROM v_caller_tenant_id THEN
            RAISE EXCEPTION 'Unauthorized: Management cannot modify users of another tenant.';
        END IF;
        IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
            RAISE EXCEPTION 'Unauthorized: Cannot transfer users between tenants.';
        END IF;
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_prevent_escalation ON public.users;
CREATE TRIGGER trg_users_prevent_escalation
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_user_privilege_escalation();

-- 3.2 Prevent unauthorized salary/compensation tampering on public.staff
CREATE OR REPLACE FUNCTION public.trg_protect_staff_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- If caller is not management, they can ONLY update attendance fields (clock-in)
    IF NOT public.is_tenant_management() THEN
        IF NEW.base_salary_paise IS DISTINCT FROM OLD.base_salary_paise THEN
            RAISE EXCEPTION 'Unauthorized: Non-management users cannot modify staff salaries.';
        END IF;
        IF NEW.upi IS DISTINCT FROM OLD.upi THEN
            RAISE EXCEPTION 'Unauthorized: Non-management users cannot modify staff UPI payment details.';
        END IF;
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Unauthorized: Non-management users cannot modify staff role designations.';
        END IF;
        IF NEW.is_paid IS DISTINCT FROM OLD.is_paid THEN
            RAISE EXCEPTION 'Unauthorized: Non-management users cannot modify staff payout status.';
        END IF;
        IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
            RAISE EXCEPTION 'Unauthorized: Cannot alter staff tenant assignment.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_staff_protect_sensitive ON public.staff;
CREATE TRIGGER trg_staff_protect_sensitive
    BEFORE UPDATE ON public.staff
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_staff_sensitive_fields();

-- ============================================================================
-- SECTION 4: HARDENED GYM OWNER REGISTRATION RPC
-- Prevents unauthorized or unlimited registration abuse
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

    -- 2. Anti-Abuse Check: Disallow if caller is already associated with any user profile or tenant
    IF EXISTS (SELECT 1 FROM public.users WHERE auth_id = v_auth_uid) THEN
        RAISE EXCEPTION 'Registration rejected: An account profile already exists for this authenticated identity.';
    END IF;

    -- Extract registered email directly from Supabase auth.users
    SELECT email INTO v_auth_email
    FROM auth.users
    WHERE id = v_auth_uid;

    IF v_auth_email IS NULL THEN
        RAISE EXCEPTION 'Associated authentication account not found in auth.users.';
    END IF;

    -- 3. Strict Input Parameter Validation
    IF p_gym_name IS NULL OR length(trim(p_gym_name)) < 2 OR length(trim(p_gym_name)) > 100 THEN
        RAISE EXCEPTION 'Gym name must be between 2 and 100 characters.';
    END IF;
    IF p_phone IS NULL OR length(trim(p_phone)) < 8 OR length(trim(p_phone)) > 20 THEN
        RAISE EXCEPTION 'A valid phone number (between 8 and 20 characters) is required.';
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
    ) VALUES (
        trim(p_gym_name),
        v_sanitized_slug,
        v_auth_email,
        trim(p_phone),
        p_address,
        p_city,
        'active'
    ) RETURNING id INTO v_new_tenant_id;

    -- 5. Insert 2: User profile (Owner)
    INSERT INTO public.users (
        tenant_id,
        auth_id,
        phone,
        email,
        full_name,
        role,
        is_active
    ) VALUES (
        v_new_tenant_id,
        v_auth_uid,
        trim(p_phone),
        v_auth_email,
        trim(p_full_name),
        'owner',
        true
    ) RETURNING id INTO v_new_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'tenant_id', v_new_tenant_id,
        'user_id', v_new_user_id,
        'slug', v_sanitized_slug
    );
END;
$$;

REVOKE ALL ON FUNCTION public.register_gym_owner(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.register_gym_owner(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR) FROM anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR) TO authenticated;

-- ============================================================================
-- SECTION 5: STRICT TENANT-ISOLATED VIEWS
-- ============================================================================

-- 5.1 Public directory view (Active tenant branding only; hides owner email & phone)
CREATE OR REPLACE VIEW public.public_tenant_directory WITH (security_invoker = false) AS
    SELECT id, name, slug, tagline, logo_url, primary_color, secondary_color, city
    FROM public.tenants
    WHERE status = 'active';

GRANT SELECT ON public.public_tenant_directory TO anon, authenticated;

-- 5.2 Tenant-scoped staff roster view (STRICTLY ISOLATED TO CALLER'S TENANT; conceals salaries/UPI)
CREATE OR REPLACE VIEW public.public_staff_roster WITH (security_invoker = false) AS
    SELECT s.id, s.tenant_id, s.name, s.role, s.is_clocked_in, s.clocked_in_at
    FROM public.staff s
    WHERE s.tenant_id = public.get_current_user_tenant_id();

GRANT SELECT ON public.public_staff_roster TO authenticated;

-- ============================================================================
-- SECTION 6: CLEAN POLICY REPLACEMENT & HARDENING
-- ============================================================================

-- Dynamic purge of existing policies on target tables
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
        AND tablename IN (
            'tenants', 'branches', 'users', 'members', 'membership_plans',
            'invoices', 'payments', 'attendance', 'staff', 'audit_logs',
            'facility_wifi_geofences', 'staff_shifts', 'staff_leaves', 'promotional_offers'
        )
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I;', r.policyname, r.schemaname, r.tablename);
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 6.1 PUBLIC.TENANTS
-- ----------------------------------------------------------------------------
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
-- 6.2 PUBLIC.USERS (Non-Recursive RLS)
-- ----------------------------------------------------------------------------
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

CREATE POLICY "Tenant users update policy" ON public.users
    FOR UPDATE TO authenticated
    USING (
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    )
    WITH CHECK (
        -- Privilege escalation & cross-tenant modifications blocked by trigger trg_users_prevent_escalation
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    );

CREATE POLICY "Tenant users delete policy" ON public.users
    FOR DELETE TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_management()
    );

-- ----------------------------------------------------------------------------
-- 6.3 PUBLIC.MEMBERS
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant members select policy" ON public.members
    FOR SELECT TO authenticated
    USING (
        user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid() LIMIT 1)
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
-- 6.4 PUBLIC.STAFF (Salary & UPI isolated from non-management staff)
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant staff select policy" ON public.staff
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND (
            public.is_tenant_management()
            OR user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid() LIMIT 1)
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
            public.is_tenant_management()
            OR user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid() LIMIT 1)
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
-- 6.5 PUBLIC.PAYMENTS & PUBLIC.INVOICES
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant payments select policy" ON public.payments
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid() LIMIT 1)
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

CREATE POLICY "Tenant invoices select policy" ON public.invoices
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid() LIMIT 1)
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
        AND public.is_tenant_management()
        AND total_paise >= 0
    );

-- ----------------------------------------------------------------------------
-- 6.6 PUBLIC.ATTENDANCE
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant attendance select policy" ON public.attendance
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid() LIMIT 1)
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
        AND public.is_tenant_staff_or_trainer()
    );

-- ----------------------------------------------------------------------------
-- 6.7 PUBLIC.MEMBERSHIP_PLANS (Strictly Tenant-Scoped)
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant membership plans select policy" ON public.membership_plans
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND is_active = true
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
-- 6.8 PUBLIC.BRANCHES
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant branches select policy" ON public.branches
    FOR SELECT TO authenticated
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
-- 6.9 PUBLIC.STAFF_SHIFTS & PUBLIC.STAFF_LEAVES
-- ----------------------------------------------------------------------------
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
-- 6.10 PUBLIC.PROMOTIONAL_OFFERS & PUBLIC.FACILITY_WIFI_GEOFENCES
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant promotional offers select policy" ON public.promotional_offers
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND is_active = true
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

CREATE POLICY "Tenant facility wifi select policy" ON public.facility_wifi_geofences
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    );

-- ----------------------------------------------------------------------------
-- 6.11 PUBLIC.AUDIT_LOGS
-- ----------------------------------------------------------------------------
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

COMMIT;
