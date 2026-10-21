-- ============================================================================
-- R3P FITNESS — AUTOMATED SQL SECURITY TEST SUITE (STAGING-ONLY SPECIFICATION V3)
-- File: security_remediation/03_SQL_SECURITY_TEST_SUITE.sql
-- Purpose: Validates RLS policies, tenant boundaries, anti-escalation triggers,
--          staff salary protection, registration anti-abuse, and member ownership.
--
-- TARGET ENVIRONMENT: Isolated Staging Database ONLY.
-- DO NOT EXECUTE ON PRODUCTION DATABASE.
-- ALL ASSERTIONS RUN WITHIN A TRANSACTION THAT EXPLICITLY ROLLS BACK AT THE END.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- FIXTURE SETUP: TWO COMPLETE TENANTS, USERS, MEMBERS, STAFF & PAYMENTS
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    -- Tenants
    v_t1 UUID := 'a0000000-0000-0000-0000-000000000001';
    v_t2 UUID := 'b0000000-0000-0000-0000-000000000002';
    
    -- Auth UIDs
    v_auth_owner_1 UUID := '11111111-1111-1111-1111-111111111101';
    v_auth_trainer_1 UUID := '11111111-1111-1111-1111-111111111102';
    v_auth_member_1 UUID := '11111111-1111-1111-1111-111111111103';
    v_auth_owner_2 UUID := '22222222-2222-2222-2222-222222222201';
    v_auth_member_2 UUID := '22222222-2222-2222-2222-222222222203';

    -- Profile IDs
    v_user_owner_1 UUID;
    v_user_trainer_1 UUID;
    v_user_member_1 UUID;
    v_user_owner_2 UUID;
    v_user_member_2 UUID;

    -- Member IDs
    v_m1 UUID;
    v_m2 UUID;

    -- Staff IDs
    v_s1 UUID;
BEGIN
    -- 1. Create Test Tenants
    INSERT INTO public.tenants (id, name, slug, owner_email, phone, address, city, status)
    VALUES 
        (v_t1, 'Staging Test Gym Alpha', 'test-gym-alpha', 'owner1@alpha.fit', '+91 91111 11111', 'Block A', 'Pune', 'active'),
        (v_t2, 'Staging Test Gym Beta', 'test-gym-beta', 'owner2@beta.fit', '+91 92222 22222', 'Block B', 'Bangalore', 'active')
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

    -- 2. Create User Profiles
    INSERT INTO public.users (id, tenant_id, auth_id, phone, email, full_name, role, is_active)
    VALUES
        (gen_random_uuid(), v_t1, v_auth_owner_1, '+91 91111 11111', 'owner1@alpha.fit', 'Alpha Owner', 'owner', true)
    RETURNING id INTO v_user_owner_1;

    INSERT INTO public.users (id, tenant_id, auth_id, phone, email, full_name, role, is_active)
    VALUES
        (gen_random_uuid(), v_t1, v_auth_trainer_1, '+91 91111 22222', 'trainer1@alpha.fit', 'Alpha Trainer', 'trainer', true)
    RETURNING id INTO v_user_trainer_1;

    INSERT INTO public.users (id, tenant_id, auth_id, phone, email, full_name, role, is_active)
    VALUES
        (gen_random_uuid(), v_t1, v_auth_member_1, '+91 91111 33333', 'member1@alpha.fit', 'Alpha Member One', 'member', true)
    RETURNING id INTO v_user_member_1;

    INSERT INTO public.users (id, tenant_id, auth_id, phone, email, full_name, role, is_active)
    VALUES
        (gen_random_uuid(), v_t2, v_auth_owner_2, '+91 92222 11111', 'owner2@beta.fit', 'Beta Owner', 'owner', true)
    RETURNING id INTO v_user_owner_2;

    INSERT INTO public.users (id, tenant_id, auth_id, phone, email, full_name, role, is_active)
    VALUES
        (gen_random_uuid(), v_t2, v_auth_member_2, '+91 92222 33333', 'member2@beta.fit', 'Beta Member Two', 'member', true)
    RETURNING id INTO v_user_member_2;

    -- 3. Create Linked Members
    INSERT INTO public.members (id, tenant_id, user_id, name, phone, plan_name, due_amount_paise, status, expiry_date)
    VALUES 
        (gen_random_uuid(), v_t1, v_user_member_1, 'Alpha Member One', '+91 91111 33333', 'Pro', 199900, 'active', CURRENT_DATE + 30)
    RETURNING id INTO v_m1;

    INSERT INTO public.members (id, tenant_id, user_id, name, phone, plan_name, due_amount_paise, status, expiry_date)
    VALUES 
        (gen_random_uuid(), v_t2, v_user_member_2, 'Beta Member Two', '+91 92222 33333', 'Elite', 0, 'active', CURRENT_DATE + 30)
    RETURNING id INTO v_m2;

    -- 4. Create Staff with sensitive salaries
    INSERT INTO public.staff (id, tenant_id, user_id, name, role, phone, base_salary_paise, upi, is_active)
    VALUES
        (gen_random_uuid(), v_t1, v_user_trainer_1, 'Alpha Trainer', 'trainer', '+91 91111 22222', 4500000, 'trainer1@upi', true)
    RETURNING id INTO v_s1;

    -- 5. Create Payments Ledger Entries (using additive member_id column)
    INSERT INTO public.payments (id, tenant_id, member_id, member_name, amount_paise, mode, reference_utr)
    VALUES
        (gen_random_uuid(), v_t1, v_m1, 'Alpha Member One', 199900, 'upi', 'UTR-ALPHA-001'),
        (gen_random_uuid(), v_t2, v_m2, 'Beta Member Two', 499900, 'upi', 'UTR-BETA-002');

    -- 6. Create Membership Plans for both tenants
    INSERT INTO public.membership_plans (id, tenant_id, name, duration_days, price_paise, is_active)
    VALUES
        (gen_random_uuid(), v_t1, 'Alpha Pro Annual', 365, 1999900, true),
        (gen_random_uuid(), v_t2, 'Beta Elite Annual', 365, 2499900, true);
END $$;

-- ----------------------------------------------------------------------------
-- TEST SECTION 1: ANONYMOUS ACCESS RESTRICTIONS
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claim.sub" = '';

DO $$
DECLARE
    v_members_count INT;
    v_staff_count INT;
    v_payments_count INT;
    v_tenants_count INT;
    v_plans_count INT;
    v_public_dir_count INT;
BEGIN
    SELECT count(*) INTO v_members_count FROM public.members;
    IF v_members_count > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Anon read on public.members permitted (% rows returned)!', v_members_count;
    END IF;

    SELECT count(*) INTO v_staff_count FROM public.staff;
    IF v_staff_count > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Anon read on public.staff permitted (% rows returned)!', v_staff_count;
    END IF;

    SELECT count(*) INTO v_payments_count FROM public.payments;
    IF v_payments_count > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Anon read on public.payments permitted (% rows returned)!', v_payments_count;
    END IF;

    SELECT count(*) INTO v_tenants_count FROM public.tenants;
    IF v_tenants_count > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Anon read on public.tenants permitted (% rows returned)!', v_tenants_count;
    END IF;

    SELECT count(*) INTO v_plans_count FROM public.membership_plans;
    IF v_plans_count > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Anon read on public.membership_plans permitted (% rows returned)!', v_plans_count;
    END IF;

    SELECT count(*) INTO v_public_dir_count FROM public.public_tenant_directory;
    IF v_public_dir_count = 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Anon cannot read public_tenant_directory view!';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST SECTION 2: CROSS-TENANT DATA ISOLATION (TENANT 1 OWNER CONTEXT)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111101';

DO $$
DECLARE
    v_t2 UUID := 'b0000000-0000-0000-0000-000000000002';
    v_t2_members INT;
    v_t2_payments INT;
    v_t2_plans INT;
    v_insert_blocked BOOLEAN := false;
BEGIN
    -- Verify Tenant 1 Owner cannot view Tenant 2 members
    SELECT count(*) INTO v_t2_members FROM public.members WHERE tenant_id = v_t2;
    IF v_t2_members > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Tenant 1 Owner can read Tenant 2 members (% rows)!', v_t2_members;
    END IF;

    -- Verify Tenant 1 Owner cannot view Tenant 2 payments
    SELECT count(*) INTO v_t2_payments FROM public.payments WHERE tenant_id = v_t2;
    IF v_t2_payments > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Tenant 1 Owner can read Tenant 2 payments (% rows)!', v_t2_payments;
    END IF;

    -- Verify Tenant 1 Owner cannot view Tenant 2 plans
    SELECT count(*) INTO v_t2_plans FROM public.membership_plans WHERE tenant_id = v_t2;
    IF v_t2_plans > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Tenant 1 Owner leaked Tenant 2 membership plans (% rows)!', v_t2_plans;
    END IF;

    -- Verify Tenant 1 Owner cannot insert records into Tenant 2
    BEGIN
        INSERT INTO public.members (tenant_id, name, phone, plan_name, due_amount_paise, expiry_date)
        VALUES (v_t2, 'Rogue Member', '+91 99999 99999', 'Basic', 0, CURRENT_DATE + 30);
    EXCEPTION WHEN insufficient_privilege OR check_violation THEN
        v_insert_blocked := true;
    END;

    IF NOT v_insert_blocked THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Tenant 1 Owner was able to insert into Tenant 2!';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST SECTION 3: ROLE PRIVILEGE SEPARATION & STAFF SENSITIVE DATA
-- ----------------------------------------------------------------------------
-- 3.1 Trainer Context: Roster view is strictly scoped to Tenant 1
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111102';

DO $$
DECLARE
    v_t2 UUID := 'b0000000-0000-0000-0000-000000000002';
    v_t2_staff_roster INT;
    v_salary_tamper_blocked BOOLEAN := false;
BEGIN
    -- Verify public_staff_roster does NOT expose Tenant 2 staff
    SELECT count(*) INTO v_t2_staff_roster FROM public.public_staff_roster WHERE tenant_id = v_t2;
    IF v_t2_staff_roster > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Trainer leaked staff from Tenant 2 in public_staff_roster (% rows)!', v_t2_staff_roster;
    END IF;

    -- Verify trainer cannot increase their own salary
    BEGIN
        UPDATE public.staff
        SET base_salary_paise = 9999999
        WHERE user_id = (SELECT id FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111102');
    EXCEPTION WHEN OTHERS THEN
        v_salary_tamper_blocked := true;
    END;

    IF NOT v_salary_tamper_blocked THEN
        IF EXISTS (
            SELECT 1 FROM public.staff 
            WHERE user_id = (SELECT id FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111102')
            AND base_salary_paise = 9999999
        ) THEN
            RAISE EXCEPTION 'ASSERTION FAILED: Trainer successfully tampered with their own base salary!';
        END IF;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST SECTION 4: ANTI-PRIVILEGE ESCALATION ON PUBLIC.USERS
-- ----------------------------------------------------------------------------
-- Impersonate Alpha Member
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111103';

DO $$
DECLARE
    v_escalation_blocked BOOLEAN := false;
    v_safe_update_succeeded BOOLEAN := false;
BEGIN
    -- 4.1 Member attempts role escalation to owner (Must be rejected)
    BEGIN
        UPDATE public.users
        SET role = 'owner'
        WHERE auth_id = '11111111-1111-1111-1111-111111111103';
    EXCEPTION WHEN OTHERS THEN
        v_escalation_blocked := true;
    END;

    IF NOT v_escalation_blocked THEN
        IF EXISTS (
            SELECT 1 FROM public.users
            WHERE auth_id = '11111111-1111-1111-1111-111111111103'
            AND role = 'owner'
        ) THEN
            RAISE EXCEPTION 'ASSERTION FAILED: Member successfully escalated self to owner!';
        END IF;
    END IF;

    -- 4.2 Member updates permitted self-service field (full_name) (Positive test)
    UPDATE public.users
    SET full_name = 'Alpha Member Renamed'
    WHERE auth_id = '11111111-1111-1111-1111-111111111103';

    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE auth_id = '11111111-1111-1111-1111-111111111103'
        AND full_name = 'Alpha Member Renamed'
    ) THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Legitimate self-profile update failed for member!';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST SECTION 5: MEMBER RECORD & PAYMENT OWNERSHIP
-- ----------------------------------------------------------------------------
-- Impersonate Alpha Member
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111103';

DO $$
DECLARE
    v_visible_payments INT;
    v_other_member_payments INT;
    v_my_member_id UUID;
BEGIN
    SELECT id INTO v_my_member_id FROM public.members WHERE user_id IN (
        SELECT id FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111103'
    );

    -- Must only see own payment records
    SELECT count(*) INTO v_visible_payments FROM public.payments WHERE member_id = v_my_member_id;
    SELECT count(*) INTO v_other_member_payments FROM public.payments WHERE member_id != v_my_member_id;

    IF v_visible_payments = 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Member cannot see their own payment history!';
    END IF;

    IF v_other_member_payments > 0 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Member leaked % peer payment records!', v_other_member_payments;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST SECTION 6: REGISTRATION RPC ABUSE & DUPLICATE PREVENTION
-- ----------------------------------------------------------------------------
-- Attempt registration while already registered (Must be rejected)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111101';

DO $$
DECLARE
    v_re_reg_blocked BOOLEAN := false;
BEGIN
    BEGIN
        PERFORM public.register_gym_owner('Rogue Second Gym', 'rogue-gym', '+91 99999 88888');
    EXCEPTION WHEN OTHERS THEN
        v_re_reg_blocked := true;
    END;

    IF NOT v_re_reg_blocked THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Existing owner was able to create unlimited duplicate tenants via register_gym_owner!';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- ALWAYS ROLL BACK: ZERO PERSISTENT TEST RESIDUE IN DATABASE
-- ----------------------------------------------------------------------------
ROLLBACK;
