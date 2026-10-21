-- ============================================================================
-- R3P FITNESS (KREW/MESH) — COMPLETE DATABASE MIGRATION & SECURITY CONSOLIDATION
-- File: security_remediation/R3P_COMPLETE_DATABASE_MIGRATION.sql
-- Compatibility: Supabase PostgreSQL (ylbrdxextihroqpvxbut.supabase.co)
-- Execution Environment: Supabase Dashboard -> SQL Editor
-- Target Architecture: Multi-Tenant SaaS with Strict Row-Level Security (RLS)
--
-- SUMMARY OF MODULES SUPPORTED:
-- 1. Tenants (Gyms / SaaS Customer Accounts, Multi-Branch, Branding, Feature Flags)
-- 2. User Profiles & Role Mapping (Linked to auth.users, Escalation Barriers)
-- 3. Confidential Member Profiles & Dues Management (Phone, Health, Plan, Check-in)
-- 4. Membership Plans & Dynamic Pricing (Tiers, Duration, Paise Pricing, Feature Arrays)
-- 5. Sequential Invoices & GST Tax Records (Tenant-Isolated FY Numbering)
-- 6. Immutable Payments Ledger (UPI, Cash, Reference UTR, Reversals, Member FK)
-- 7. Live Attendance & Rotating Check-in Tokens (QR Verification, Timestamps)
-- 8. Staff Management, Attendance & Confidential Compensation (Salaries, UPI, Floor Status)
-- 9. Immutable Audit Trails (Actor Tracking, JSONB Payload Changes)
-- 10. Facility Wi-Fi Geofence Verification (BSSID Geotagging)
-- 11. Staff Shifts & Leave Tracking
-- 12. In-App Promotional Offer Wall & Claimed Perks
-- 13. Hardened Public Views:
--     - public_tenant_directory (Public active gym directory, hides owner contact)
--     - public_staff_roster (Floor roster for trainers/front-desk, omits salary & UPI)
-- 14. Hardened Security Definer RPCs:
--     - register_gym_owner (Atomic registration with slug collision retry)
--     - clock_in_out_staff (Strictly validated attendance toggling)
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1: EXTENSIONS & BASE PREREQUISITES
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- SECTION 2: CORE MULTI-TENANT TABLES (IF NOT EXISTS)
-- ============================================================================

-- 2.1 Tenants (Gyms / SaaS Customers)
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    tagline VARCHAR(255),
    logo_url TEXT,
    primary_color VARCHAR(16) DEFAULT '#ff5500',
    secondary_color VARCHAR(16) DEFAULT '#7c3aed',
    owner_email VARCHAR(255) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    gst_number VARCHAR(32),
    address TEXT,
    city VARCHAR(128) NOT NULL,
    status VARCHAR(32) DEFAULT 'active',
    feature_flags JSONB DEFAULT '{"biometric": false, "whatsapp_auto": true, "diet_engine": true, "online_booking": true}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.2 Branches
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(32),
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geofence_radius_meters INT DEFAULT 150,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.3 Users Profile & Role Mapping (Linked to auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    auth_id UUID,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'member',
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.4 Members Profile & Health Data (Confidential)
CREATE TABLE IF NOT EXISTS public.members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    email VARCHAR(255),
    plan_name VARCHAR(128) DEFAULT 'Pro Plan',
    status VARCHAR(32) DEFAULT 'active',
    expiry_date DATE NOT NULL,
    attendance_count INT DEFAULT 0,
    is_checked_in BOOLEAN DEFAULT false,
    checked_in_at VARCHAR(32),
    total_paid_paise BIGINT NOT NULL DEFAULT 0,
    due_amount_paise BIGINT NOT NULL DEFAULT 0,
    risk_score VARCHAR(16) DEFAULT 'low',
    emergency_contact VARCHAR(255),
    height_cm NUMERIC(5, 2),
    weight_kg NUMERIC(5, 2),
    fitness_goal VARCHAR(128),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2.5 Membership Plans
CREATE TABLE IF NOT EXISTS public.membership_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    duration_days INT NOT NULL DEFAULT 30,
    price_paise BIGINT NOT NULL CHECK (price_paise >= 0),
    joining_fee_paise BIGINT DEFAULT 0 CHECK (joining_fee_paise >= 0),
    max_freeze_days INT DEFAULT 0,
    class_credits INT DEFAULT 0,
    features JSONB DEFAULT '["Gym floor access"]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.6 Invoices (Sequential tenant-specific FY numbering)
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_number VARCHAR(64) NOT NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_name VARCHAR(255) NOT NULL,
    subtotal_paise BIGINT NOT NULL CHECK (subtotal_paise >= 0),
    tax_gst_paise BIGINT DEFAULT 0 CHECK (tax_gst_paise >= 0),
    total_paise BIGINT NOT NULL CHECK (total_paise >= 0),
    paid_paise BIGINT DEFAULT 0 CHECK (paid_paise >= 0),
    due_paise BIGINT DEFAULT 0 CHECK (due_paise >= 0),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(32) DEFAULT 'paid',
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_tenant_invoice UNIQUE (tenant_id, invoice_number)
);

-- 2.7 Immutable Payment Ledger (Transactions)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    invoice_number VARCHAR(64),
    member_name VARCHAR(255) NOT NULL,
    amount_paise BIGINT NOT NULL,
    mode VARCHAR(32) NOT NULL DEFAULT 'upi',
    reference_utr VARCHAR(128),
    notes TEXT,
    is_reversal BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.8 Attendance Records & Rotating Check-in Tokens
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    member_name VARCHAR(255) NOT NULL,
    check_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    check_out_at TIMESTAMPTZ,
    method VARCHAR(32) DEFAULT 'qr_rotating',
    is_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.9 Staff Records & Shift Attendance
CREATE TABLE IF NOT EXISTS public.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(128) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    email VARCHAR(255),
    upi VARCHAR(128),
    base_salary_paise BIGINT NOT NULL DEFAULT 0,
    is_clocked_in BOOLEAN DEFAULT false,
    clocked_in_at VARCHAR(32),
    is_paid BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.10 Audit Log (Immutable append-only trail)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    actor_user_id VARCHAR(128),
    actor_role VARCHAR(32),
    action VARCHAR(64) NOT NULL,
    entity VARCHAR(64) NOT NULL,
    entity_id VARCHAR(128),
    changes JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.11 Facility Wi-Fi Geofence & Geotag Table
CREATE TABLE IF NOT EXISTS public.facility_wifi_geofences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE CASCADE,
    ssid VARCHAR(128) NOT NULL,
    bssid VARCHAR(64) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.12 Staff Shifts Table
CREATE TABLE IF NOT EXISTS public.staff_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE,
    shift_name VARCHAR(64) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    days_of_week INT[] DEFAULT '{1,2,3,4,5,6}'::int[]
);

-- 2.13 Staff Leaves Table
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

-- 2.14 Promotional Offers & Offer Wall Table
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

-- ============================================================================
-- SECTION 3: ADDITIVE COLUMNS & SAFE TABLE ALTERATIONS
-- ============================================================================

-- Ensure member_id exists on payments (resolves schema mismatch)
ALTER TABLE public.payments
    ADD COLUMN IF NOT EXISTS member_id UUID REFERENCES public.members(id) ON DELETE SET NULL;

-- Ensure user_id exists on staff (binds staff to users for self-attendance)
ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

-- Ensure email exists on staff
ALTER TABLE public.staff
    ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Ensure features JSONB exists on membership_plans
ALTER TABLE public.membership_plans
    ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '["Gym floor access"]'::jsonb;

-- Preflight validation: Check for duplicate auth_id values in public.users
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

-- Standardize role check constraint on public.users
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users
    ADD CONSTRAINT users_role_check
    CHECK (role IN (
        'super_admin', 'owner', 'manager', 'front_desk', 'trainer', 'member',
        'adm', 'emp', 'stf', 'mem'
    ));

-- Unique constraint on auth_id to prevent multi-profile collisions per auth identity
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS uq_users_auth_id;

ALTER TABLE public.users
    ADD CONSTRAINT uq_users_auth_id UNIQUE (auth_id);

-- ============================================================================
-- SECTION 4: PERFORMANCE INDEXES (COVERING ALL FOREIGN KEYS & RLS PREDICATES)
-- ============================================================================
-- 4.1 Core Tenant & User Indexes
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_tenant_role ON public.users(tenant_id, role);

-- 4.2 Members Indexes
CREATE INDEX IF NOT EXISTS idx_members_user_id ON public.members(user_id);
CREATE INDEX IF NOT EXISTS idx_members_tenant_id ON public.members(tenant_id);

-- 4.3 Staff Indexes
CREATE INDEX IF NOT EXISTS idx_staff_user_id ON public.staff(user_id);
CREATE INDEX IF NOT EXISTS idx_staff_tenant_id ON public.staff(tenant_id);

-- 4.4 Payments Indexes
CREATE INDEX IF NOT EXISTS idx_payments_tenant_id ON public.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_member_id ON public.payments(member_id);

-- 4.5 Attendance Indexes
CREATE INDEX IF NOT EXISTS idx_attendance_tenant_id ON public.attendance(tenant_id);
CREATE INDEX IF NOT EXISTS idx_attendance_member_id ON public.attendance(member_id);

-- 4.6 Invoices Indexes (Covering tenant_id and member_id foreign keys)
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_id ON public.invoices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoices_member_id ON public.invoices(member_id);

-- 4.7 Membership Plans & Offers Indexes
CREATE INDEX IF NOT EXISTS idx_membership_plans_tenant_id ON public.membership_plans(tenant_id);
CREATE INDEX IF NOT EXISTS idx_promotional_offers_tenant_id ON public.promotional_offers(tenant_id);

-- 4.8 Branches & Geofences Covering Indexes (Fixes 0001_unindexed_foreign_keys)
CREATE INDEX IF NOT EXISTS idx_branches_tenant_id ON public.branches(tenant_id);
CREATE INDEX IF NOT EXISTS idx_facility_wifi_geofences_tenant_id ON public.facility_wifi_geofences(tenant_id);
CREATE INDEX IF NOT EXISTS idx_facility_wifi_geofences_branch_id ON public.facility_wifi_geofences(branch_id);

-- 4.9 Staff Shifts & Leaves Covering Indexes (Fixes 0001_unindexed_foreign_keys)
CREATE INDEX IF NOT EXISTS idx_staff_shifts_tenant_id ON public.staff_shifts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_staff_shifts_staff_id ON public.staff_shifts(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_leaves_tenant_id ON public.staff_leaves(tenant_id);
CREATE INDEX IF NOT EXISTS idx_staff_leaves_staff_id ON public.staff_leaves(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_leaves_approved_by ON public.staff_leaves(approved_by);

-- 4.10 Audit Logs Covering Index (Fixes 0001_unindexed_foreign_keys)
CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id ON public.audit_logs(tenant_id);

-- ============================================================================
-- SECTION 5: TRUSTED AUTHORIZATION HELPER FUNCTIONS
-- ============================================================================

-- 5.1 Helper: Get verified tenant_id of current active caller
CREATE OR REPLACE FUNCTION public.get_current_user_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT tenant_id FROM public.users
    WHERE auth_id = auth.uid()
    AND is_active = true
    LIMIT 1;
$$;

-- 5.2 Helper: Get verified canonical role of current active authenticated caller
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS VARCHAR
LANGUAGE sql
STABLE
SECURITY INVOKER
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

-- 5.3 Helper: Check if caller is gym management or super_admin
CREATE OR REPLACE FUNCTION public.is_tenant_management()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE auth_id = auth.uid()
        AND is_active = true
        AND role IN ('owner', 'manager', 'super_admin', 'adm')
    );
$$;

-- 5.4 Helper: Check if caller is operational staff or super_admin
CREATE OR REPLACE FUNCTION public.is_tenant_staff_or_trainer()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE auth_id = auth.uid()
        AND is_active = true
        AND role IN ('owner', 'manager', 'front_desk', 'trainer', 'super_admin', 'adm', 'emp', 'stf')
    );
$$;

-- 5.5 Helper: Get internal user profile ID of current active caller
CREATE OR REPLACE FUNCTION public.get_current_profile_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
    SELECT id FROM public.users
    WHERE auth_id = auth.uid()
    AND is_active = true
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_current_user_tenant_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_user_tenant_id() TO authenticated;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_management() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_tenant_management() TO authenticated;

REVOKE ALL ON FUNCTION public.is_tenant_staff_or_trainer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_tenant_staff_or_trainer() TO authenticated;

REVOKE ALL ON FUNCTION public.get_current_profile_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_profile_id() TO authenticated;

-- ============================================================================
-- SECTION 6: SENSITIVE ATTRIBUTE TRIGGERS (USERS & STAFF)
-- ============================================================================

-- 6.1 Prevent Privilege Escalation & Cross-Tenant Switching on public.users
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

REVOKE ALL ON FUNCTION public.trg_prevent_user_privilege_escalation() FROM PUBLIC, anon, authenticated;

-- 6.2 Protect Staff Salaries and Enforce Strict Attendance-Only Updates on public.staff
CREATE OR REPLACE FUNCTION public.trg_protect_staff_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
    -- Strict allowlist: Non-management users can ONLY update attendance fields (is_clocked_in, clocked_in_at).
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

REVOKE ALL ON FUNCTION public.trg_protect_staff_sensitive_fields() FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- SECTION 7: HARDENED BUSINESS RPC FUNCTIONS
-- ============================================================================

-- 7.1 Atomic Gym Owner Registration RPC
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
SECURITY INVOKER
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

    -- 2. Anti-Abuse Guard: Disallow if caller is already associated with any user profile
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
    v_base_slug := lower(regexp_replace(coalesce(p_slug, ''), '[^a-zA-Z0-9-]', '-', 'g'));
    IF length(v_base_slug) < 3 THEN
        v_base_slug := lower(regexp_replace(trim(p_gym_name), '[^a-zA-Z0-9-]', '-', 'g'));
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

-- 7.2 Secure Tenant-Validated Staff Clock-In / Clock-Out RPC
CREATE OR REPLACE FUNCTION public.clock_in_out_staff(
    p_staff_id UUID,
    p_is_clocked_in BOOLEAN,
    p_clocked_in_at TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
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
        NULL;
    ELSIF v_caller_role IN ('owner', 'manager', 'adm') THEN
        IF v_target_staff.tenant_id IS DISTINCT FROM v_caller_tenant_id THEN
            RAISE EXCEPTION 'Unauthorized: Management cannot update staff of another tenant.'
                USING ERRCODE = '42501';
        END IF;
    ELSE
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

REVOKE ALL ON FUNCTION public.clock_in_out_staff(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clock_in_out_staff(UUID, BOOLEAN, TEXT) TO authenticated;

-- ============================================================================
-- SECTION 8: STRICT TENANT-ISOLATED VIEWS
-- ============================================================================

-- 8.1 Public directory view (Active gym branding; hides owner personal contact)
CREATE OR REPLACE VIEW public.public_tenant_directory WITH (security_invoker = true) AS
    SELECT id, name, slug, tagline, logo_url, primary_color, secondary_color, city
    FROM public.tenants
    WHERE status = 'active';

-- 8.2 Public staff roster view (Omits base_salary_paise and upi)
CREATE OR REPLACE VIEW public.public_staff_roster WITH (security_invoker = true) AS
    SELECT s.id, s.tenant_id, s.name, s.role, s.phone, s.email, s.is_clocked_in, s.clocked_in_at
    FROM public.staff s
    WHERE s.tenant_id = public.get_current_user_tenant_id();

GRANT SELECT ON public.public_tenant_directory TO anon, authenticated;
GRANT SELECT ON public.public_staff_roster TO authenticated;

-- ============================================================================
-- SECTION 9: ENABLE ROW-LEVEL SECURITY ON ALL TABLES
-- ============================================================================
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
-- SECTION 10: TARGETED POLICY CLEANUP
-- ============================================================================
DROP POLICY IF EXISTS "Allow public read access to active tenant" ON public.tenants;
DROP POLICY IF EXISTS "Tenant read policy" ON public.tenants;
DROP POLICY IF EXISTS "Allow authenticated gym owner onboarding insert" ON public.tenants;
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
DROP POLICY IF EXISTS "Tenant membership plans select policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans write policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans insert policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans update policy" ON public.membership_plans;
DROP POLICY IF EXISTS "Tenant membership plans delete policy" ON public.membership_plans;

DROP POLICY IF EXISTS "Allow public read branches" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches insert" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches update" ON public.branches;
DROP POLICY IF EXISTS "Strict tenant branches delete" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches select policy" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches write policy" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches insert policy" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches update policy" ON public.branches;
DROP POLICY IF EXISTS "Tenant branches delete policy" ON public.branches;

DROP POLICY IF EXISTS "Allow public read access to active tenant wifi" ON public.facility_wifi_geofences;
DROP POLICY IF EXISTS "Tenant facility wifi select policy" ON public.facility_wifi_geofences;

DROP POLICY IF EXISTS "Allow public read access to staff shifts" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts select policy" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts write policy" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts insert policy" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts update policy" ON public.staff_shifts;
DROP POLICY IF EXISTS "Tenant staff shifts delete policy" ON public.staff_shifts;

DROP POLICY IF EXISTS "Allow tenant staff leaves read" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves select policy" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves insert policy" ON public.staff_leaves;
DROP POLICY IF EXISTS "Tenant staff leaves update policy" ON public.staff_leaves;

DROP POLICY IF EXISTS "Allow public read access to promotional offers" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers select policy" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers write policy" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers insert policy" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers update policy" ON public.promotional_offers;
DROP POLICY IF EXISTS "Tenant promotional offers delete policy" ON public.promotional_offers;

DROP POLICY IF EXISTS "Allow tenant audit write" ON public.audit_logs;
DROP POLICY IF EXISTS "Strict tenant audit insert" ON public.audit_logs;
DROP POLICY IF EXISTS "Tenant audit select policy" ON public.audit_logs;
DROP POLICY IF EXISTS "Tenant audit insert policy" ON public.audit_logs;

-- ============================================================================
-- SECTION 11: CANONICAL PRODUCTION ROW-LEVEL SECURITY POLICIES
-- ============================================================================

-- 11.1 PUBLIC.TENANTS
CREATE POLICY "Tenant read policy" ON public.tenants
    FOR SELECT TO anon, authenticated
    USING (
        status = 'active'
        OR id = public.get_current_user_tenant_id()
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Allow authenticated gym owner onboarding insert" ON public.tenants
    FOR INSERT TO authenticated
    WITH CHECK ((select auth.uid()) IS NOT NULL AND length(trim(name)) > 0);

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

-- 11.2 PUBLIC.USERS
CREATE POLICY "Tenant users select policy" ON public.users
    FOR SELECT TO authenticated
    USING (
        auth_id = (select auth.uid())
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
        auth_id = (select auth.uid())
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        auth_id = (select auth.uid())
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant users delete policy" ON public.users
    FOR DELETE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- 11.3 PUBLIC.MEMBERS
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

-- 11.4 PUBLIC.STAFF
CREATE POLICY "Tenant staff select policy" ON public.staff
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
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

-- 11.5 PUBLIC.PAYMENTS & PUBLIC.INVOICES
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

-- 11.6 PUBLIC.ATTENDANCE
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

-- 11.7 PUBLIC.MEMBERSHIP_PLANS
CREATE POLICY "Tenant membership plans select policy" ON public.membership_plans
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND is_active = true)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant membership plans insert policy" ON public.membership_plans
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant membership plans update policy" ON public.membership_plans
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant membership plans delete policy" ON public.membership_plans
    FOR DELETE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- 11.8 PUBLIC.BRANCHES
CREATE POLICY "Tenant branches select policy" ON public.branches
    FOR SELECT TO authenticated
    USING (
        tenant_id = public.get_current_user_tenant_id()
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant branches insert policy" ON public.branches
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant branches update policy" ON public.branches
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant branches delete policy" ON public.branches
    FOR DELETE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

-- 11.9 PUBLIC.STAFF_SHIFTS & PUBLIC.STAFF_LEAVES
CREATE POLICY "Tenant staff shifts select policy" ON public.staff_shifts
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff shifts insert policy" ON public.staff_shifts
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff shifts update policy" ON public.staff_shifts
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant staff shifts delete policy" ON public.staff_shifts
    FOR DELETE TO authenticated
    USING (
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

-- 11.10 PUBLIC.PROMOTIONAL_OFFERS & PUBLIC.FACILITY_WIFI_GEOFENCES
CREATE POLICY "Tenant promotional offers select policy" ON public.promotional_offers
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND is_active = true)
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant promotional offers insert policy" ON public.promotional_offers
    FOR INSERT TO authenticated
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant promotional offers update policy" ON public.promotional_offers
    FOR UPDATE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    )
    WITH CHECK (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant promotional offers delete policy" ON public.promotional_offers
    FOR DELETE TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
        OR public.get_current_user_role() = 'super_admin'
    );

CREATE POLICY "Tenant facility wifi select policy" ON public.facility_wifi_geofences
    FOR SELECT TO authenticated
    USING (
        (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_staff_or_trainer())
        OR public.get_current_user_role() = 'super_admin'
    );

-- 11.11 PUBLIC.AUDIT_LOGS
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

-- ============================================================================
-- SECTION 12: OPTIONAL INITIAL SEED DATA (SAFE UPSERT)
-- ============================================================================
INSERT INTO public.tenants (id, slug, name, tagline, city, phone, owner_email, gst_number)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'r3p-pune',
    'R3P Fitness by KREW/MESH',
    'Precision Athletic & Gym Club',
    'Pune, Maharashtra',
    '+91 98765 43210',
    'owner@r3p.fit',
    '27AABCR3P1231Z1'
) ON CONFLICT (slug) DO NOTHING;

COMMIT;
