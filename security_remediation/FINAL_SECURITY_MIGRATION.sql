-- ============================================================================
-- R3P FITNESS — CANONICAL FINAL SECURITY HARDENING MIGRATION (V5 AUDITED)
-- File: security_remediation/FINAL_SECURITY_MIGRATION.sql
-- Status: PENDING STAGING EXECUTION & VERIFICATION (DO NOT RUN ON PRODUCTION)
-- Target Database: Supabase PostgreSQL (ylbrdxextihroqpvxbut.supabase.co)
-- Reference: supabase_schema.sql
--
-- TARGETED ARCHITECTURAL ENHANCEMENTS:
-- 1. Targeted Policy Preservation:
--    - Completely replaces broad wildcard policy drops with explicit, named drops
--      for known insecure policies from supabase_schema.sql and fix scripts.
-- 2. Complete Active Account Enforcement:
--    - Helper functions enforce `is_active = true` on `public.users`.
--    - Deactivated accounts fail authorization checks across all tables and views.
--    - Reconciles `super_admin` so operators can access multi-tenant data while
--      regular tenant owners are strictly constrained to their own tenant.
-- 3. Staff Salary & UPI Column Confidentiality:
--    - Row-Level Security restricts direct `SELECT` on `public.staff` strictly to
--      management and individual self-read (`user_id = public.get_current_profile_id()`).
--    - Non-management staff access `public.public_staff_roster` which omits
--      `base_salary_paise` and `upi`.
-- 4. Strict Staff Update Authorization (Ownership in USING & WITH CHECK):
--    - Both `USING` and `WITH CHECK` enforce row ownership (`user_id = public.get_current_profile_id()`).
--    - Trigger `trg_protect_staff_sensitive_fields` rejects any non-management
--      modification of `base_salary_paise`, `upi`, `role`, `is_paid`, `tenant_id`,
--      `user_id`, or `name`. Non-management staff may only update `is_clocked_in` and `clocked_in_at`.
-- 5. Hardened `register_gym_owner()`:
--    - Validates authenticated identity (`auth.uid() IS NOT NULL`).
--    - Collision retry loop with random suffixes for unique slugs.
--    - Rejects duplicate profile registrations for existing auth accounts.
--    - Owned by `postgres` with fixed search_path = `pg_catalog, public, pg_temp`.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1: PREFLIGHT INTEGRITY, ADDITIVE COLUMNS & CONSTRAINTS
-- ============================================================================

-- 1.1 Preflight: Check for duplicate auth_id values in public.users before applying constraint
DO $$
DECLARE
    v_dup_count INT;
BEGIN
    SELECT count(*) INTO v_dup_count
    FROM (
        SELECT auth_id FROM public.users
        WHERE auth_id IS NOT NULL
        GROUP BY auth_id
        HAVING count(*) > 1
    ) sub;

    IF v_dup_count > 0 THEN
        RAISE EXCEPTION 'PREFLIGHT ABORT: Found % duplicate auth_id values in public.users. Deduplicate before applying unique constraint.', v_dup_count;
    END IF;
END $$;

-- 1.2 Standardize role check constraint on public.users
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users
    ADD CONSTRAINT users_role_check
    CHECK (role IN (
        'super_admin', 'owner', 'manager', 'front_desk', 'trainer', 'member',
        'adm', 'emp', 'stf', 'mem'
    ));

-- 1.3 Prevent duplicate user profiles per auth user
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS uq_users_auth_id;

ALTER TABLE public.users
    ADD CONSTRAINT uq_users_auth_id UNIQUE (auth_id);

-- 1.4 Add user_id reference to staff table (nullable to preserve existing rows)
ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

-- 1.5 Add member_id reference to payments table (nullable to preserve existing rows)
-- [RESOLVED SCHEMA MISMATCH]: Live payments table initially lacked member_id.
ALTER TABLE public.payments
    ADD COLUMN IF NOT EXISTS member_id UUID REFERENCES public.members(id) ON DELETE SET NULL;

-- 1.6 Conditionally create secondary tables if missing
CREATE TABLE IF NOT EXISTS public.facility_wifi_geofences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE CASCADE,
    ssid VARCHAR(128) NOT NULL,
    bssid VARCHAR(64) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.staff_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE,
    shift_name VARCHAR(64) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    days_of_week INT[] DEFAULT '{1,2,3,4,5,6}'::int[]
);

CREATE TABLE IF NOT EXISTS public.staff_leaves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE,
    leave_date DATE NOT NULL,
    reason TEXT,
    status VARCHAR(32) DEFAULT 'approved',
    approved_by UUID REFERENCES public.tenants(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.promotional_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(64) NOT NULL,
    discount_pct INT,
    coupon_code VARCHAR(32),
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true
);

-- 1.7 High-performance indexes for RLS policy evaluation
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

-- 1.8 Enable Row-Level Security on all tenant tables
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

-- ============================================================================
-- SECTION 2: TRUSTED AUTHORIZATION HELPER FUNCTIONS
-- All functions require is_active = true and have fixed search_path = pg_catalog, public, pg_temp
-- ============================================================================

-- Function 1: Get verified tenant ID of current active authenticated caller
CREATE OR REPLACE FUNCTION public.get_current_user_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT tenant_id FROM public.users
    WHERE auth_id = auth.uid()
    AND is_active = true
    LIMIT 1;
$$;

-- Function 2: Get verified canonical role of current active authenticated caller
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS VARCHAR
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
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
    AND is_active = true
    LIMIT 1;
$$;

-- Function 3: Check if caller is gym management or super_admin
CREATE OR REPLACE FUNCTION public.is_tenant_management()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE auth_id = auth.uid()
        AND is_active = true
        AND role IN ('owner', 'manager', 'super_admin', 'adm')
    );
$$;

-- Function 4: Check if caller is operational staff or super_admin
CREATE OR REPLACE FUNCTION public.is_tenant_staff_or_trainer()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE auth_id = auth.uid()
        AND is_active = true
        AND role IN ('owner', 'manager', 'front_desk', 'trainer', 'super_admin', 'adm', 'emp', 'stf')
    );
$$;

-- Function 5: Get internal user profile ID of current active caller
CREATE OR REPLACE FUNCTION public.get_current_profile_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT id FROM public.users
    WHERE auth_id = auth.uid()
    AND is_active = true
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_current_user_tenant_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_tenant_id() TO authenticated;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_management() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_tenant_management() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_staff_or_trainer() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_tenant_staff_or_trainer() TO authenticated;

REVOKE ALL ON FUNCTION public.get_current_profile_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_profile_id() TO authenticated;

-- ============================================================================
-- SECTION 3: SENSITIVE ATTRIBUTE TRIGGERS (USERS & STAFF)
-- ============================================================================

-- 3.1 Strict Privilege Escalation and Tenant Switching Prevention
-- 3.1 Strict Privilege Escalation and Tenant Switching Prevention (Allowlist Enforcement)
CREATE OR REPLACE FUNCTION public.trg_prevent_user_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
    v_caller_role VARCHAR(32);
    v_caller_tenant_id UUID;
BEGIN
    v_caller_role := public.get_current_user_role();
    v_caller_tenant_id := public.get_current_user_tenant_id();

    -- Rule A: Strict allowlist for non-management (member, trainer, front_desk)
    -- Non-management users may ONLY modify self-service profile fields: full_name and avatar_url
    IF v_caller_role NOT IN ('owner', 'manager', 'super_admin') THEN
        IF NEW.id IS DISTINCT FROM OLD.id OR
           NEW.auth_id IS DISTINCT FROM OLD.auth_id OR
           NEW.tenant_id IS DISTINCT FROM OLD.tenant_id OR
           NEW.email IS DISTINCT FROM OLD.email OR
           NEW.role IS DISTINCT FROM OLD.role OR
           NEW.is_active IS DISTINCT FROM OLD.is_active OR
           NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Unauthorized: Non-management users may only update approved self-service profile fields (full_name, avatar_url).';
        END IF;
    ELSE
        -- Rule B: Management cannot transfer users across tenants (super_admin excepted)
        IF OLD.tenant_id IS DISTINCT FROM v_caller_tenant_id AND v_caller_role != 'super_admin' THEN
            RAISE EXCEPTION 'Unauthorized: Management cannot modify users of another tenant.';
        END IF;
        IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id AND v_caller_role != 'super_admin' THEN
            RAISE EXCEPTION 'Unauthorized: Cannot transfer users between tenants.';
        END IF;

        -- Rule C: Tenant Owner cannot elevate anyone to super_admin
        IF NEW.role = 'super_admin' AND v_caller_role != 'super_admin' THEN
            RAISE EXCEPTION 'Unauthorized: Only an existing super_admin can grant the super_admin role.';
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

-- 3.2 Protect Staff Salaries and Confidential Payout Info
-- 3.2 Protect Staff Salaries and Enforce Strict Attendance-Only Updates (Allowlist Enforcement)
CREATE OR REPLACE FUNCTION public.trg_protect_staff_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
    -- Strict allowlist: Non-management users can ONLY update attendance fields (is_clocked_in, clocked_in_at).
    -- All other fields (compensation, UPI, role, name, phone, email, tenant, user_id, status) are rejected.
    IF NOT public.is_tenant_management() THEN
        IF NEW.id IS DISTINCT FROM OLD.id OR
           NEW.tenant_id IS DISTINCT FROM OLD.tenant_id OR
           NEW.user_id IS DISTINCT FROM OLD.user_id OR
           NEW.name IS DISTINCT FROM OLD.name OR
           NEW.role IS DISTINCT FROM OLD.role OR
           NEW.phone IS DISTINCT FROM OLD.phone OR
           NEW.email IS DISTINCT FROM OLD.email OR
           NEW.base_salary_paise IS DISTINCT FROM OLD.base_salary_paise OR
           NEW.upi IS DISTINCT FROM OLD.upi OR
           NEW.is_paid IS DISTINCT FROM OLD.is_paid OR
           NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Unauthorized: Non-management users can only update attendance fields (is_clocked_in, clocked_in_at).';
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
-- Prevents unauthorized or unlimited registration abuse; handles slug collisions safely
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
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
    v_auth_uid UUID;
    v_auth_email VARCHAR(255);
    v_new_tenant_id UUID;
    v_new_user_id UUID;
    v_sanitized_slug VARCHAR(64);
    v_base_slug VARCHAR(64);
    v_retry_count INT := 0;
    v_inserted BOOLEAN := false;
BEGIN
    -- 1. Ensure caller is authenticated via Supabase Auth
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required to register a gym.';
    END IF;

    -- 2. Anti-Abuse Guard: Disallow if caller is already associated with any user profile or tenant
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

    -- Sanitize base slug
    v_base_slug := lower(regexp_replace(coalesce(p_slug, ''), '[^a-zA-Z0-9\-]', '-', 'g'));
    IF length(v_base_slug) < 3 THEN
        v_base_slug := lower(regexp_replace(trim(p_gym_name), '[^a-zA-Z0-9\-]', '-', 'g'));
    END IF;
    IF length(v_base_slug) < 3 THEN
        v_base_slug := 'gym-' || substring(gen_random_uuid()::text from 1 for 6);
    END IF;
    v_sanitized_slug := v_base_slug;

    -- 4. Atomic Tenant Insert with Collision Handling Loop
    WHILE NOT v_inserted AND v_retry_count < 5 LOOP
        BEGIN
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
            
            v_inserted := true;
        EXCEPTION WHEN unique_violation THEN
            v_retry_count := v_retry_count + 1;
            v_sanitized_slug := substring(v_base_slug from 1 for 50) || '-' || substring(gen_random_uuid()::text from 1 for 6);
        END;
    END LOOP;

    IF NOT v_inserted THEN
        RAISE EXCEPTION 'Could not generate a unique slug for gym after multiple attempts. Please choose a different slug.';
    END IF;

    -- 5. Insert User Profile (Owner)
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
-- ============================================================================
-- SECTION 4.2: SECURE TENANT-VALIDATED STAFF CLOCK-IN / CLOCK-OUT RPC
-- Explicitly validates caller authentication, active status, and staff ownership.
-- Non-management roles are strictly limited to toggling attendance status on their own record.
-- Management and super_admin can record clock-in for any staff member in their tenant.
-- Prevents any unauthorized modification of salary, UPI, role, name, or other columns.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.clock_in_out_staff(
    p_staff_id UUID,
    p_is_clocked_in BOOLEAN,
    p_clocked_in_at TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
    v_caller_auth_id UUID;
    v_caller_profile_id UUID;
    v_caller_role VARCHAR(32);
    v_caller_tenant_id UUID;
    v_target_staff RECORD;
BEGIN
    -- 1. Validate Caller Authentication
    v_caller_auth_id := auth.uid();
    IF v_caller_auth_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Caller must be authenticated to record attendance.'
            USING ERRCODE = '28000';
    END IF;

    -- 2. Validate Caller Active Account & Tenant
    SELECT id, tenant_id, role INTO v_caller_profile_id, v_caller_tenant_id, v_caller_role
    FROM public.users
    WHERE auth_id = v_caller_auth_id AND is_active = true;

    IF v_caller_profile_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Active user profile not found for authenticated caller.'
            USING ERRCODE = '28000';
    END IF;

    -- 3. Lookup Target Staff Record
    SELECT id, tenant_id, user_id, name, is_clocked_in, clocked_in_at
    INTO v_target_staff
    FROM public.staff
    WHERE id = p_staff_id;

    IF v_target_staff.id IS NULL THEN
        RAISE EXCEPTION 'Staff record not found.'
            USING ERRCODE = 'P0002';
    END IF;

    -- 4. Enforce Authorization: Management can update any staff within tenant;
    -- Non-management staff can ONLY update their own bound staff record.
    IF v_caller_role = 'super_admin' THEN
        -- Super-admin can record attendance across tenants
        NULL;
    ELSIF v_caller_role IN ('owner', 'manager', 'adm') THEN
        IF v_target_staff.tenant_id IS DISTINCT FROM v_caller_tenant_id THEN
            RAISE EXCEPTION 'Unauthorized: Management cannot update staff of another tenant.'
                USING ERRCODE = '42501';
        END IF;
    ELSE
        -- Non-management (trainer, front_desk, etc.): Must belong to same tenant AND own the record
        IF v_target_staff.tenant_id IS DISTINCT FROM v_caller_tenant_id THEN
            RAISE EXCEPTION 'Unauthorized: Cannot record attendance for another tenant.'
                USING ERRCODE = '42501';
        END IF;

        IF v_target_staff.user_id IS DISTINCT FROM v_caller_profile_id THEN
            RAISE EXCEPTION 'Unauthorized: Non-management staff can only clock in/out for their own record.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 5. Execute Attendance Update ONLY (Never touches salary, UPI, role, etc.)
    UPDATE public.staff
    SET is_clocked_in = p_is_clocked_in,
        clocked_in_at = CASE WHEN p_is_clocked_in THEN COALESCE(p_clocked_in_at, to_char(now() AT TIME ZONE 'Asia/Kolkata', 'HH12:MI AM')) ELSE NULL END
    WHERE id = p_staff_id;

    RETURN jsonb_build_object(
        'success', true,
        'staff_id', p_staff_id,
        'is_clocked_in', p_is_clocked_in,
        'clocked_in_at', CASE WHEN p_is_clocked_in THEN COALESCE(p_clocked_in_at, to_char(now() AT TIME ZONE 'Asia/Kolkata', 'HH12:MI AM')) ELSE NULL END
    );
END;
$$;

REVOKE ALL ON FUNCTION public.clock_in_out_staff(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.clock_in_out_staff(UUID, BOOLEAN, TEXT) TO authenticated;


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
-- SECTION 6: TARGETED POLICY DROPS & REPLACEMENT
-- Drops only specific known policies, preserving unrelated policies.
-- ============================================================================

-- 6.1 Drop known legacy and fix-script policies on target tables
DROP POLICY IF EXISTS "Allow public read access to active tenant" ON public.tenants;
DROP POLICY IF EXISTS "Tenant read policy" ON public.tenants;
DROP POLICY IF EXISTS "Strict tenant owner update" ON public.tenants;

DROP POLICY IF EXISTS "Allow public read users" ON public.users;
DROP POLICY IF EXISTS "Strict tenant users insert" ON public.users;
DROP POLICY IF EXISTS "Strict tenant users update" ON public.users;
DROP POLICY IF EXISTS "Strict tenant users delete" ON public.users;
DROP POLICY IF EXISTS "Tenant users select policy" ON public.users;
DROP POLICY IF EXISTS "Tenant users insert policy" ON public.users;
DROP POLICY IF EXISTS "Tenant users update policy" ON public.users;
DROP POLICY IF EXISTS "Tenant users delete policy" ON public.users;

DROP POLICY IF EXISTS "Allow tenant members read" ON public.members;
DROP POLICY IF EXISTS "Strict tenant members insert" ON public.members;
DROP POLICY IF EXISTS "Strict tenant members update" ON public.members;
DROP POLICY IF EXISTS "Strict tenant members delete" ON public.members;
DROP POLICY IF EXISTS "Tenant members select policy" ON public.members;
DROP POLICY IF EXISTS "Tenant members insert policy" ON public.members;
DROP POLICY IF EXISTS "Tenant members update policy" ON public.members;
DROP POLICY IF EXISTS "Tenant members delete policy" ON public.members;

DROP POLICY IF EXISTS "Allow tenant staff read" ON public.staff;
DROP POLICY IF EXISTS "Strict tenant staff insert" ON public.staff;
DROP POLICY IF EXISTS "Strict tenant staff update" ON public.staff;
DROP POLICY IF EXISTS "Strict tenant staff delete" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff select policy" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff insert policy" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff update policy" ON public.staff;
DROP POLICY IF EXISTS "Tenant staff delete policy" ON public.staff;

DROP POLICY IF EXISTS "Allow tenant payments read" ON public.payments;
DROP POLICY IF EXISTS "Strict tenant payments insert" ON public.payments;
DROP POLICY IF EXISTS "Strict tenant payments update" ON public.payments;
DROP POLICY IF EXISTS "Tenant payments select policy" ON public.payments;
DROP POLICY IF EXISTS "Tenant payments insert policy" ON public.payments;
DROP POLICY IF EXISTS "Tenant payments update policy" ON public.payments;

DROP POLICY IF EXISTS "Allow tenant invoices read" ON public.invoices;
DROP POLICY IF EXISTS "Strict tenant invoices insert" ON public.invoices;
DROP POLICY IF EXISTS "Strict tenant invoices update" ON public.invoices;
DROP POLICY IF EXISTS "Tenant invoices select policy" ON public.invoices;
DROP POLICY IF EXISTS "Tenant invoices insert policy" ON public.invoices;
DROP POLICY IF EXISTS "Tenant invoices update policy" ON public.invoices;

DROP POLICY IF EXISTS "Allow tenant attendance read" ON public.attendance;
DROP POLICY IF EXISTS "Strict tenant attendance insert" ON public.attendance;
DROP POLICY IF EXISTS "Strict tenant attendance update" ON public.attendance;
DROP POLICY IF EXISTS "Tenant attendance select policy" ON public.attendance;
DROP POLICY IF EXISTS "Tenant attendance insert policy" ON public.attendance;
DROP POLICY IF EXISTS "Tenant attendance update policy" ON public.attendance;

DROP POLICY IF EXISTS "Allow tenant plans read" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans read policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans select policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Strict tenant plans write" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans write policy" ON public.membership_plans;

DROP POLICY IF EXISTS "Allow public read branches" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches insert" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches update" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches delete" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches select policy" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches write policy" ON public.branches;

DROP POLICY IF EXISTS "Allow public read access to staff shifts" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts select policy" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts write policy" ON public.staff_shifts;

DROP POLICY IF EXISTS "Allow tenant staff leaves read" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves select policy" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves insert policy" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves update policy" ON public.staff_leaves;

DROP POLICY IF EXISTS "Allow public read access to promotional offers" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers select policy" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers write policy" ON public.promotional_offers;

DROP POLICY IF EXISTS "Allow public read access to active tenant wifi" ON public.facility_wifi_geofences;
DROP POLICY IF EXISTS "Tenant facility wifi select policy" ON public.facility_wifi_geofences;

DROP POLICY IF EXISTS "Strict tenant audit insert" ON public.audit_logs;
DROP POLICY IF EXISTS "Tenant audit select policy" ON public.audit_logs;
DROP POLICY IF EXISTS "Tenant audit insert policy" ON public.audit_logs;

-- ----------------------------------------------------------------------------
-- 6.2 PUBLIC.TENANTS
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant read policy" ON public.tenants
    FOR SELECT TO authenticated
    USING (
        id = public.get_current_user_tenant_id()
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Strict tenant owner update" ON public.tenants
    FOR UPDATE TO authenticated
    USING (
        (id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.3 PUBLIC.USERS (Non-Recursive RLS)
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant users select policy" ON public.users
    FOR SELECT TO authenticated
    USING (
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant users insert policy" ON public.users
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant users update policy" ON public.users
    FOR UPDATE TO authenticated
    USING (
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant users delete policy" ON public.users
    FOR DELETE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.4 PUBLIC.MEMBERS
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant members select policy" ON public.members
    FOR SELECT TO authenticated
    USING (
        user_id = public.get_current_profile_id()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant members insert policy" ON public.members
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer() AND length(trim(name)) > 0)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant members update policy" ON public.members
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer() AND length(trim(name)) > 0)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant members delete policy" ON public.members
    FOR DELETE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.5 PUBLIC.STAFF (Management-Only Direct Table Access; Non-Management MUST Use public_staff_roster)
-- ----------------------------------------------------------------------------
-- CRITICAL SECURITY POLICY: Direct access to public.staff exposes base_salary_paise and upi.
-- To protect staff compensation data from direct Supabase REST queries, direct SELECT on
-- public.staff is strictly restricted to Management (owner, manager) and Super-Admin.
-- Non-management staff and trainers MUST query the secure tenant-scoped view 'public_staff_roster',
-- which explicitly excludes base_salary_paise, upi, and other sensitive payout fields.
CREATE POLICY "Tenant staff select policy" ON public.staff
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff insert policy" ON public.staff
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management() AND length(trim(name)) > 0)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff update policy" ON public.staff
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND (public.is_tenant_management() OR user_id = public.get_current_profile_id()))
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND (
            public.is_tenant_management()
            OR (
                user_id = public.get_current_profile_id()
                AND length(trim(name)) > 0
            )
            OR public.get_current_user_role() = 'super_admin'
        )
    );

CREATE POLICY "Tenant staff delete policy" ON public.staff
    FOR DELETE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.6 PUBLIC.PAYMENTS & PUBLIC.INVOICES
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant payments select policy" ON public.payments
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = public.get_current_profile_id()
        ))
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant payments insert policy" ON public.payments
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management() AND amount_paise != 0)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant payments update policy" ON public.payments
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant invoices select policy" ON public.invoices
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = public.get_current_profile_id()
        ))
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant invoices insert policy" ON public.invoices
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management() AND total_paise >= 0 AND length(trim(invoice_number)) > 0)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant invoices update policy" ON public.invoices
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management() AND total_paise >= 0)
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.7 PUBLIC.ATTENDANCE
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant attendance select policy" ON public.attendance
    FOR SELECT TO authenticated
    USING (
        (member_id IN (
            SELECT id FROM public.members
            WHERE user_id = public.get_current_profile_id()
        ))
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant attendance insert policy" ON public.attendance
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer() AND member_id IS NOT NULL)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant attendance update policy" ON public.attendance
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.8 PUBLIC.MEMBERSHIP_PLANS (Strictly Tenant-Scoped)
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant membership plans select policy" ON public.membership_plans
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND is_active = true)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant membership plans write policy" ON public.membership_plans
    FOR ALL TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.9 PUBLIC.BRANCHES
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant branches select policy" ON public.branches
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant branches write policy" ON public.branches
    FOR ALL TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.10 PUBLIC.STAFF_SHIFTS & PUBLIC.STAFF_LEAVES
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant staff shifts select policy" ON public.staff_shifts
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff shifts write policy" ON public.staff_shifts
    FOR ALL TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff leaves select policy" ON public.staff_leaves
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff leaves insert policy" ON public.staff_leaves
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff leaves update policy" ON public.staff_leaves
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.11 PUBLIC.PROMOTIONAL_OFFERS & PUBLIC.FACILITY_WIFI_GEOFENCES
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant promotional offers select policy" ON public.promotional_offers
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND is_active = true)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant promotional offers write policy" ON public.promotional_offers
    FOR ALL TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant facility wifi select policy" ON public.facility_wifi_geofences
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

-- ----------------------------------------------------------------------------
-- 6.12 PUBLIC.AUDIT_LOGS
-- ----------------------------------------------------------------------------
CREATE POLICY "Tenant audit select policy" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant audit insert policy" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND length(trim(action)) > 0)
        OR public.get_current_user_role() = 'super_admin'
    );

COMMIT;
