-- ============================================================================
-- R3P FITNESS (KREW/MESH) — MULTI-TENANT PRODUCTION POSTGRESQL SCHEMA (SUPABASE)
-- STRICT RLS, INTEGER PAISE FOR ALL MONETARY VALUES, AUDIT LOGGING
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enum types
DO $$ BEGIN
    CREATE TYPE tenant_status AS ENUM ('trial', 'active', 'past_due', 'suspended');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('super_admin', 'owner', 'manager', 'front_desk', 'trainer', 'member');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE membership_status AS ENUM ('pending_payment', 'active', 'expiring', 'expired', 'frozen', 'cancelled', 'renewed');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_mode AS ENUM ('upi', 'cash', 'card', 'gateway', 'bank_transfer');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 1. Tenants (Gyms / SaaS Customers)
CREATE TABLE IF NOT EXISTS tenants (
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
    package_id VARCHAR(128) DEFAULT 'com.krewmesh.r3p',
    status tenant_status DEFAULT 'trial',
    trial_ends_at TIMESTAMPTZ DEFAULT (now() + interval '14 days'),
    subscription_ends_at TIMESTAMPTZ,
    grace_period_days INT DEFAULT 7,
    feature_flags JSONB DEFAULT '{"biometric": false, "whatsapp_auto": false, "diet_engine": true, "online_booking": true}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Branches
CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(32),
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geofence_radius_meters INT DEFAULT 150,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    auth_id UUID UNIQUE, -- maps to supabase auth.users if available
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    full_name VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'member',
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_tenant_phone UNIQUE (tenant_id, phone)
);

-- 4. Members Profile & Health Data (Encrypted/Confidential)
CREATE TABLE IF NOT EXISTS members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    member_code VARCHAR(32),
    dob DATE,
    gender VARCHAR(16),
    emergency_contact_name VARCHAR(128),
    emergency_contact_phone VARCHAR(32),
    health_notes TEXT, -- Medical clearance / injuries
    height_cm NUMERIC(5, 2),
    weight_kg NUMERIC(5, 2),
    fitness_goal VARCHAR(128),
    assigned_trainer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    risk_score risk_level DEFAULT 'low',
    attendance_streak_days INT DEFAULT 0,
    last_visited_at TIMESTAMPTZ,
    consent_marketing BOOLEAN DEFAULT false,
    consent_health_data BOOLEAN DEFAULT false,
    consent_photos BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Membership Plans
CREATE TABLE IF NOT EXISTS membership_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    duration_days INT NOT NULL,
    price_paise BIGINT NOT NULL CHECK (price_paise >= 0), -- Stored in paise
    joining_fee_paise BIGINT DEFAULT 0 CHECK (joining_fee_paise >= 0),
    max_freeze_days INT DEFAULT 0,
    class_credits INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Member Subscriptions (Memberships)
CREATE TABLE IF NOT EXISTS memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES membership_plans(id),
    status membership_status NOT NULL DEFAULT 'active',
    start_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    frozen_until DATE,
    total_frozen_days INT DEFAULT 0,
    amount_paid_paise BIGINT NOT NULL DEFAULT 0,
    due_amount_paise BIGINT NOT NULL DEFAULT 0 CHECK (due_amount_paise >= 0),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT valid_dates CHECK (expiry_date >= start_date)
);

-- 7. Invoices (Sequential tenant-specific FY numbering)
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id UUID REFERENCES members(id) ON DELETE SET NULL,
    invoice_number VARCHAR(64) NOT NULL, -- e.g. R3P/26-27/0001
    financial_year VARCHAR(16) NOT NULL, -- e.g. 26-27
    seq_number INT NOT NULL,
    subtotal_paise BIGINT NOT NULL CHECK (subtotal_paise >= 0),
    tax_gst_paise BIGINT DEFAULT 0 CHECK (tax_gst_paise >= 0),
    discount_paise BIGINT DEFAULT 0 CHECK (discount_paise >= 0),
    total_paise BIGINT NOT NULL CHECK (total_paise >= 0),
    paid_paise BIGINT DEFAULT 0 CHECK (paid_paise >= 0),
    due_paise BIGINT DEFAULT 0 CHECK (due_paise >= 0),
    status VARCHAR(32) DEFAULT 'issued',
    pdf_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_tenant_invoice UNIQUE (tenant_id, invoice_number)
);

-- 8. Immutable Payment Ledger (Transactions)
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    member_id UUID REFERENCES members(id) ON DELETE SET NULL,
    amount_paise BIGINT NOT NULL, -- negative for reversing entries/refunds
    mode payment_mode NOT NULL,
    reference_utr VARCHAR(128),
    notes TEXT,
    recorded_by_user_id UUID REFERENCES users(id),
    is_reversal BOOLEAN DEFAULT false,
    reversal_parent_id UUID REFERENCES payments(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. Daily Cash Register / Closing
CREATE TABLE IF NOT EXISTS cash_closings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    closing_date DATE NOT NULL,
    opening_balance_paise BIGINT NOT NULL DEFAULT 0,
    expected_cash_paise BIGINT NOT NULL,
    counted_cash_paise BIGINT NOT NULL,
    discrepancy_paise BIGINT GENERATED ALWAYS AS (counted_cash_paise - expected_cash_paise) STORED,
    verified_by_user_id UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 10. Attendance Records & Rotating Check-in Tokens
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    member_id UUID REFERENCES members(id) ON DELETE CASCADE,
    check_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    check_out_at TIMESTAMPTZ,
    verified_method VARCHAR(32) DEFAULT 'qr_scan', -- qr_scan, manual, geofence
    checked_in_by_user_id UUID REFERENCES users(id),
    manual_override_reason TEXT,
    is_stale_closed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 11. Staff Shifts & Attendance
CREATE TABLE IF NOT EXISTS staff_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    staff_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    shift_date DATE NOT NULL,
    clock_in_at TIMESTAMPTZ,
    clock_out_at TIMESTAMPTZ,
    hours_worked NUMERIC(5, 2) DEFAULT 0,
    geofence_verified BOOLEAN DEFAULT false,
    distance_meters INT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 12. Payroll Runs & Payslips
CREATE TABLE IF NOT EXISTS payroll_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    month_year VARCHAR(16) NOT NULL, -- e.g. '2026-10'
    staff_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    base_salary_paise BIGINT NOT NULL DEFAULT 0,
    pt_commissions_paise BIGINT NOT NULL DEFAULT 0,
    incentives_paise BIGINT NOT NULL DEFAULT 0,
    deductions_paise BIGINT NOT NULL DEFAULT 0,
    net_salary_paise BIGINT NOT NULL,
    payout_mode payment_mode DEFAULT 'bank_transfer',
    payout_reference VARCHAR(128),
    is_locked BOOLEAN DEFAULT false,
    approved_by_user_id UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_staff_month UNIQUE (tenant_id, staff_user_id, month_year)
);

-- 13. Audit Log (Immutable append-only trail)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(64) NOT NULL, -- e.g. 'refund_issued', 'manual_attendance_override', 'price_modified'
    target_entity VARCHAR(64) NOT NULL,
    target_id UUID,
    changes JSONB,
    ip_address VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES — ABSOLUTE TENANT ISOLATION
-- ============================================================================

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_closings ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's tenant_id from auth metadata
CREATE OR REPLACE FUNCTION current_tenant_id() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('app.current_tenant_id', true), '')::UUID;
$$ LANGUAGE sql STABLE;

-- Tenant Isolation Policies
CREATE POLICY tenant_isolation_branches ON branches FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_users ON users FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_members ON members FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_plans ON membership_plans FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_memberships ON memberships FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_invoices ON invoices FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_payments ON payments FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_closings ON cash_closings FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_attendance ON attendance FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_shifts ON staff_shifts FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_payroll ON payroll_runs FOR ALL USING (tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation_audit ON audit_logs FOR ALL USING (tenant_id = current_tenant_id());

-- Super admin bypass policy for multi-tenant SaaS management
CREATE POLICY super_admin_tenants ON tenants FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE users.auth_id = auth.uid() AND users.role = 'super_admin')
);
