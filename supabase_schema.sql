-- ============================================================================
-- R3P FITNESS (KREW/MESH) — MULTI-TENANT PRODUCTION POSTGRESQL SCHEMA (SUPABASE)
-- EXECUTE THIS IN YOUR SUPABASE SQL EDITOR (Dashboard -> SQL Editor -> New Query)
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Tenants (Gyms / SaaS Customers)
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
    status VARCHAR(32) DEFAULT 'active', -- 'trial', 'active', 'past_due', 'suspended'
    feature_flags JSONB DEFAULT '{"biometric": false, "whatsapp_auto": true, "diet_engine": true, "online_booking": true}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Branches
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

-- 3. Users Profile & Role Mapping
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    auth_id UUID, -- Links to Supabase auth.users(id)
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'member', -- 'super_admin', 'owner', 'manager', 'front_desk', 'trainer', 'member'
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Members Profile & Health Data (Confidential)
CREATE TABLE IF NOT EXISTS public.members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    email VARCHAR(255),
    plan_name VARCHAR(128) DEFAULT 'Pro Plan',
    status VARCHAR(32) DEFAULT 'active', -- 'active', 'expiring', 'expired', 'frozen'
    expiry_date DATE NOT NULL,
    attendance_count INT DEFAULT 0,
    is_checked_in BOOLEAN DEFAULT false,
    checked_in_at VARCHAR(32),
    total_paid_paise BIGINT NOT NULL DEFAULT 0, -- Stored in Integer Paise
    due_amount_paise BIGINT NOT NULL DEFAULT 0,  -- Stored in Integer Paise
    risk_score VARCHAR(16) DEFAULT 'low',
    emergency_contact VARCHAR(255),
    height_cm NUMERIC(5, 2),
    weight_kg NUMERIC(5, 2),
    fitness_goal VARCHAR(128),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Membership Plans
CREATE TABLE IF NOT EXISTS public.membership_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    duration_days INT NOT NULL,
    price_paise BIGINT NOT NULL CHECK (price_paise >= 0),
    joining_fee_paise BIGINT DEFAULT 0 CHECK (joining_fee_paise >= 0),
    max_freeze_days INT DEFAULT 0,
    class_credits INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Invoices (Sequential tenant-specific FY numbering)
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_number VARCHAR(64) NOT NULL, -- e.g. R3P/26-27/0001
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

-- 7. Immutable Payment Ledger (Transactions)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_number VARCHAR(64),
    member_name VARCHAR(255) NOT NULL,
    amount_paise BIGINT NOT NULL,
    mode VARCHAR(32) NOT NULL DEFAULT 'upi', -- upi, cash, card, gateway
    reference_utr VARCHAR(128),
    notes TEXT,
    is_reversal BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Attendance Records & Rotating Check-in Tokens
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

-- 9. Staff Records & Shift Attendance
CREATE TABLE IF NOT EXISTS public.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(128) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    upi VARCHAR(128),
    base_salary_paise BIGINT NOT NULL DEFAULT 0,
    is_clocked_in BOOLEAN DEFAULT false,
    clocked_in_at VARCHAR(32),
    is_paid BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 10. Audit Log (Immutable append-only trail)
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

-- ============================================================================
-- INITIAL SEED DATA FOR R3P FITNESS (PUNE FLAGSHIP TENANT)
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

-- Seed Initial Plans
INSERT INTO public.membership_plans (tenant_id, name, duration_days, price_paise, joining_fee_paise, max_freeze_days, class_credits)
VALUES 
    ('a0000000-0000-0000-0000-000000000001', 'Basic Monthly', 30, 99900, 49900, 7, 0),
    ('a0000000-0000-0000-0000-000000000001', 'Pro Quarterly', 90, 279900, 0, 14, 5),
    ('a0000000-0000-0000-0000-000000000001', 'Elite Annual', 365, 999900, 0, 45, 20)
ON CONFLICT DO NOTHING;

-- Seed Initial Members
INSERT INTO public.members (tenant_id, name, phone, email, plan_name, status, expiry_date, attendance_count, is_checked_in, checked_in_at, total_paid_paise, due_amount_paise)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Aarav Mehta', '+91 99221 33445', 'aarav@r3p.fit', 'Pro Plan', 'active', '2026-11-20', 18, true, '07:15 AM', 199900, 0),
    ('a0000000-0000-0000-0000-000000000001', 'Diya Sharma', '+91 98220 54321', 'diya@r3p.fit', 'Elite Annual', 'active', '2027-02-15', 24, true, '08:30 AM', 1499900, 0),
    ('a0000000-0000-0000-0000-000000000001', 'Rohan Patil', '+91 98901 12345', 'rohan@r3p.fit', 'Basic Monthly', 'expiring', '2026-10-22', 4, false, '', 99900, 99900),
    ('a0000000-0000-0000-0000-000000000001', 'Sneha Iyer', '+91 97654 32109', 'sneha@r3p.fit', 'Pro Plan', 'active', '2026-12-05', 12, true, '09:10 AM', 199900, 0),
    ('a0000000-0000-0000-0000-000000000001', 'Kabir Singh', '+91 98234 56789', 'kabir@r3p.fit', 'Basic Monthly', 'expired', '2026-10-12', 2, false, '', 99900, 99900)
ON CONFLICT DO NOTHING;

-- Seed Initial Staff
INSERT INTO public.staff (tenant_id, name, role, phone, upi, base_salary_paise, is_clocked_in, clocked_in_at, is_paid)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Rahul Desai', 'Head Trainer', '+91 98220 45671', 'rahul@okaxis', 3500000, true, '06:00 AM', true),
    ('a0000000-0000-0000-0000-000000000001', 'Priya Kadam', 'Front Desk & CRM', '+91 98220 99887', 'priya@okhdfc', 2200000, true, '07:00 AM', true),
    ('a0000000-0000-0000-0000-000000000001', 'Vikram Shinde', 'Floor Trainer', '+91 98900 11223', 'vikram@okicici', 2500000, false, '', false)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
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

-- Allow anon & authenticated users to read and write with tenant isolation
CREATE POLICY "Allow public read access to active tenant" ON public.tenants FOR SELECT USING (true);
CREATE POLICY "Allow tenant members read" ON public.members FOR SELECT USING (true);
CREATE POLICY "Allow tenant members write" ON public.members FOR ALL USING (true);
CREATE POLICY "Allow tenant staff read" ON public.staff FOR SELECT USING (true);
CREATE POLICY "Allow tenant staff write" ON public.staff FOR ALL USING (true);
CREATE POLICY "Allow tenant invoices read" ON public.invoices FOR SELECT USING (true);
CREATE POLICY "Allow tenant invoices write" ON public.invoices FOR ALL USING (true);
CREATE POLICY "Allow tenant payments read" ON public.payments FOR SELECT USING (true);
CREATE POLICY "Allow tenant payments write" ON public.payments FOR ALL USING (true);
CREATE POLICY "Allow tenant attendance read" ON public.attendance FOR SELECT USING (true);
CREATE POLICY "Allow tenant attendance write" ON public.attendance FOR ALL USING (true);
CREATE POLICY "Allow tenant plans read" ON public.membership_plans FOR SELECT USING (true);
CREATE POLICY "Allow tenant audit write" ON public.audit_logs FOR INSERT WITH CHECK (true);
