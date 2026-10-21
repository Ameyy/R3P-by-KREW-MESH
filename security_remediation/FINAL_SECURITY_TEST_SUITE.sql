-- ============================================================================
-- R3P FITNESS — CANONICAL AUTOMATED SQL SECURITY TEST SUITE (STAGING-ONLY V5)
-- File: security_remediation/FINAL_SECURITY_TEST_SUITE.sql
-- Target Database: Isolated PostgreSQL Staging Instance ONLY
-- Execution Policy: DO NOT RUN AGAINST PRODUCTION.
--                   Terminates with ROLLBACK; to leave staging completely unaltered.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- FIXTURE SETUP: TWO COMPLETE TENANTS, DISTINCT ROLES, STAFF, MEMBERS & PAYMENTS
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    -- Tenants
    v_t1 UUID := 'a0000000-0000-0000-0000-000000000001';
    v_t2 UUID := 'b0000000-0000-0000-0000-000000000002';
    
    -- Auth UIDs
    v_auth_owner_1 UUID := '11111111-1111-1111-1111-111111111101';
    v_auth_trainer_1 UUID := '11111111-1111-1111-1111-111111111102';
    v_auth_frontdesk_1 UUID := '11111111-1111-1111-1111-111111111104';
    v_auth_member_1 UUID := '11111111-1111-1111-1111-111111111103';
    v_auth_inactive_1 UUID := '11111111-1111-1111-1111-111111111199';
    v_auth_owner_2 UUID := '22222222-2222-2222-2222-222222222201';
    v_auth_member_2 UUID := '22222222-2222-2222-2222-222222222203';

    -- Profile IDs
    v_user_owner_1 UUID;
    v_user_trainer_1 UUID;
    v_user_frontdesk_1 UUID;
    v_user_member_1 UUID;
    v_user_inactive_1 UUID;
    v_user_owner_2 UUID;
    v_user_member_2 UUID;

    -- Member & Staff IDs
    v_m1 UUID;
    v_m2 UUID;
    v_s1 UUID;
BEGIN
    -- 1. Create Test Tenants
    INSERT INTO public.tenants (id, name, slug, owner_email, phone, address, city, status)
    VALUES 
        (v_t1, 'Alpha Club Pune', 'alpha-club-pune', 'owner1@alpha.fit', '+91 91111 11111', 'Baner', 'Pune', 'active'),
        (v_t2, 'Beta Club Indiranagar', 'beta-club-blr', 'owner2@beta.fit', '+91 92222 22222', 'Indiranagar', 'Bangalore', 'active')
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
        (gen_random_uuid(), v_t1, v_auth_frontdesk_1, '+91 91111 44444', 'frontdesk1@alpha.fit', 'Alpha Desk', 'front_desk', true)
    RETURNING id INTO v_user_frontdesk_1;

    INSERT INTO public.users (id, tenant_id, auth_id, phone, email, full_name, role, is_active)
    VALUES
        (gen_random_uuid(), v_t1, v_auth_member_1, '+91 91111 33333', 'member1@alpha.fit', 'Alpha Member One', 'member', true)
    RETURNING id INTO v_user_member_1;

    -- Deactivated User Profile
    INSERT INTO public.users (id, tenant_id, auth_id, phone, email, full_name, role, is_active)
    VALUES
        (gen_random_uuid(), v_t1, v_auth_inactive_1, '+91 91111 99999', 'inactive@alpha.fit', 'Alpha Inactive', 'member', false)
    RETURNING id INTO v_user_inactive_1;

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

    -- 4. Create Staff with Confidential Compensation
    INSERT INTO public.staff (id, tenant_id, user_id, name, role, phone, base_salary_paise, upi, is_active)
    VALUES
        (gen_random_uuid(), v_t1, v_user_trainer_1, 'Alpha Trainer', 'trainer', '+91 91111 22222', 4500000, 'trainer1@upi', true)
    RETURNING id INTO v_s1;

    -- 5. Create Payments Ledger Entries
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
-- TEST 1: ANONYMOUS ACCESS RESTRICTIONS
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claim.sub" = '';

DO $$
DECLARE
    v_members INT;
    v_staff INT;
    v_payments INT;
    v_tenants INT;
    v_plans INT;
    v_public_dir INT;
BEGIN
    SELECT count(*) INTO v_members FROM public.members;
    IF v_members > 0 THEN RAISE EXCEPTION 'ANON TEST FAILED: public.members leaked % rows!', v_members; END IF;

    SELECT count(*) INTO v_staff FROM public.staff;
    IF v_staff > 0 THEN RAISE EXCEPTION 'ANON TEST FAILED: public.staff leaked % rows!', v_staff; END IF;

    SELECT count(*) INTO v_payments FROM public.payments;
    IF v_payments > 0 THEN RAISE EXCEPTION 'ANON TEST FAILED: public.payments leaked % rows!', v_payments; END IF;

    SELECT count(*) INTO v_tenants FROM public.tenants;
    IF v_tenants > 0 THEN RAISE EXCEPTION 'ANON TEST FAILED: public.tenants leaked % rows!', v_tenants; END IF;

    SELECT count(*) INTO v_plans FROM public.membership_plans;
    IF v_plans > 0 THEN RAISE EXCEPTION 'ANON TEST FAILED: public.membership_plans leaked % rows!', v_plans; END IF;

    -- Positive check: public_tenant_directory must be readable
    SELECT count(*) INTO v_public_dir FROM public.public_tenant_directory;
    IF v_public_dir = 0 THEN RAISE EXCEPTION 'ANON TEST FAILED: public_tenant_directory was empty!'; END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST 2: CROSS-TENANT DATA ISOLATION (TENANT 1 OWNER CONTEXT)
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
    SELECT count(*) INTO v_t2_members FROM public.members WHERE tenant_id = v_t2;
    IF v_t2_members > 0 THEN RAISE EXCEPTION 'CROSS-TENANT FAILED: Leaked % members from Tenant 2!', v_t2_members; END IF;

    SELECT count(*) INTO v_t2_payments FROM public.payments WHERE tenant_id = v_t2;
    IF v_t2_payments > 0 THEN RAISE EXCEPTION 'CROSS-TENANT FAILED: Leaked % payments from Tenant 2!', v_t2_payments; END IF;

    SELECT count(*) INTO v_t2_plans FROM public.membership_plans WHERE tenant_id = v_t2;
    IF v_t2_plans > 0 THEN RAISE EXCEPTION 'CROSS-TENANT FAILED: Leaked % plans from Tenant 2!', v_t2_plans; END IF;

    -- Cross-tenant write must be blocked
    BEGIN
        INSERT INTO public.members (tenant_id, name, phone, plan_name, due_amount_paise, expiry_date)
        VALUES (v_t2, 'Rogue Member', '+91 99999 99999', 'Basic', 0, CURRENT_DATE + 30);
    EXCEPTION
        WHEN insufficient_privilege THEN v_insert_blocked := true;
        WHEN check_violation THEN v_insert_blocked := true;
    END;

    IF NOT v_insert_blocked THEN
        RAISE EXCEPTION 'CROSS-TENANT FAILED: Tenant 1 Owner succeeded in inserting row into Tenant 2!';
    END IF;
    -- Management Verification: Owner can read full staff row including salary/UPI
    DECLARE
        v_staff_sal BIGINT;
        v_staff_upi TEXT;
    BEGIN
        SELECT base_salary_paise, upi INTO v_staff_sal, v_staff_upi
        FROM public.staff
        WHERE tenant_id = 'a0000000-0000-0000-0000-000000000001' LIMIT 1;

        IF v_staff_sal IS NULL OR v_staff_upi IS NULL THEN
            RAISE EXCEPTION 'MANAGEMENT STAFF READ FAILED: Owner could not read staff compensation details!';
        END IF;

        -- Management can legitimately update staff details (e.g. payout status)
        UPDATE public.staff
        SET is_paid = true
        WHERE tenant_id = 'a0000000-0000-0000-0000-000000000001'
        AND name = 'Alpha Trainer';
    END;

END $$;

-- ----------------------------------------------------------------------------
-- TEST 3: STAFF SALARY PRIVACY & ROSTER VIEW ISOLATION (TRAINER CONTEXT)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111102';

DO $$
DECLARE
    v_t2 UUID := 'b0000000-0000-0000-0000-000000000002';
    v_t2_roster INT;
    v_direct_staff_rows INT;
    v_salary_tamper_blocked BOOLEAN := false;
    v_name_tamper_blocked BOOLEAN := false;
    v_own_attendance_succeeded BOOLEAN := false;
BEGIN
    -- 3a. Direct SELECT on public.staff MUST return 0 rows for non-management (Shields base_salary_paise & upi)
    SELECT count(*) INTO v_direct_staff_rows FROM public.staff;
    IF v_direct_staff_rows > 0 THEN
        RAISE EXCEPTION 'STAFF PRIVACY FAILED: Non-management trainer retrieved % rows directly from public.staff! Confidential compensation exposed.', v_direct_staff_rows;
    END IF;

    -- 3b. Roster view must not leak Tenant 2 staff
    SELECT count(*) INTO v_t2_roster FROM public.public_staff_roster WHERE tenant_id = v_t2;
    IF v_t2_roster > 0 THEN RAISE EXCEPTION 'STAFF ROSTER FAILED: Leaked % staff from Tenant 2!', v_t2_roster; END IF;

    -- 3c. Trainer cannot tamper with own salary (Assert exact error message and verify row state)
    BEGIN
        UPDATE public.staff
        SET base_salary_paise = 9999999
        WHERE user_id = public.get_current_profile_id();
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM NOT LIKE '%Non-management users can only update attendance fields%' THEN
                RAISE EXCEPTION 'STAFF SECURITY FAILED: Unexpected exception message on salary tamper: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            END IF;
            v_salary_tamper_blocked := true;
    END;

    IF NOT v_salary_tamper_blocked THEN
        RAISE EXCEPTION 'STAFF SECURITY FAILED: Trainer salary update was not rejected by trigger!';
    END IF;
    IF EXISTS (SELECT 1 FROM public.staff WHERE user_id = public.get_current_profile_id() AND base_salary_paise = 9999999) THEN
        RAISE EXCEPTION 'STAFF SECURITY FAILED: Trainer salary was modified in database!';
    END IF;

    -- 3d. Strict Update: Trainer cannot modify unapproved field (name)
    BEGIN
        UPDATE public.staff
        SET name = 'Hacked Name'
        WHERE user_id = public.get_current_profile_id();
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM NOT LIKE '%Non-management users can only update attendance fields%' THEN
                RAISE EXCEPTION 'STAFF SECURITY FAILED: Unexpected exception message on name tamper: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            END IF;
            v_name_tamper_blocked := true;
    END;

    IF NOT v_name_tamper_blocked THEN
        RAISE EXCEPTION 'STAFF SECURITY FAILED: Trainer name modification was not rejected!';
    END IF;
    IF EXISTS (SELECT 1 FROM public.staff WHERE user_id = public.get_current_profile_id() AND name = 'Hacked Name') THEN
        RAISE EXCEPTION 'STAFF SECURITY FAILED: Trainer name was modified in database!';
    END IF;

    -- 3e. Positive check: Staff can update clock-in status via direct update
    UPDATE public.staff
    SET is_clocked_in = true, clocked_in_at = '08:00 AM'
    WHERE user_id = public.get_current_profile_id();

    SELECT is_clocked_in INTO v_own_attendance_succeeded
    FROM public.staff WHERE user_id = public.get_current_profile_id();

    IF NOT v_own_attendance_succeeded THEN
        RAISE EXCEPTION 'STAFF WORKFLOW FAILED: Authorized clock-in update was rejected!';
    END IF;

    -- 3f. Positive check: Staff can execute clock_in_out_staff RPC securely
    DECLARE
        v_my_staff_id UUID;
        v_rpc_res JSONB;
    BEGIN
        SELECT id INTO v_my_staff_id FROM public.staff WHERE user_id = public.get_current_profile_id();
        v_rpc_res := public.clock_in_out_staff(v_my_staff_id, false, NULL);
        IF (v_rpc_res->>'success')::BOOLEAN IS NOT TRUE THEN
            RAISE EXCEPTION 'STAFF RPC FAILED: clock_in_out_staff returned failure: %', v_rpc_res;
        END IF;
    END;
END $$;

-- ----------------------------------------------------------------------------
-- TEST 4: DEACTIVATED ACCOUNT AUTHORIZATION FAILURE
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111199';

DO $$
DECLARE
    v_members_seen INT;
    v_payments_seen INT;
BEGIN
    -- Deactivated user profile has is_active = false; helper functions return NULL
    SELECT count(*) INTO v_members_seen FROM public.members;
    IF v_members_seen > 0 THEN
        RAISE EXCEPTION 'DEACTIVATED ACCOUNT FAILED: Inactive user was able to query public.members (% rows)!', v_members_seen;
    END IF;

    SELECT count(*) INTO v_payments_seen FROM public.payments;
    IF v_payments_seen > 0 THEN
        RAISE EXCEPTION 'DEACTIVATED ACCOUNT FAILED: Inactive user was able to query public.payments (% rows)!', v_payments_seen;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST 5: ANTI-PRIVILEGE ESCALATION & PROFILE SELF-EDITS (MEMBER CONTEXT)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111103';

DO $$
DECLARE
    v_role_escalate_blocked BOOLEAN := false;
    v_tenant_switch_blocked BOOLEAN := false;
    v_email_tamper_blocked BOOLEAN := false;
    v_active_tamper_blocked BOOLEAN := false;
    v_t2 UUID := 'b0000000-0000-0000-0000-000000000002';
BEGIN
    -- 5a. Member attempts role escalation to owner (Assert exact error message and verify row state)
    BEGIN
        UPDATE public.users SET role = 'owner' WHERE auth_id = '11111111-1111-1111-1111-111111111103';
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM NOT LIKE '%Non-management users may only update approved self-service profile fields%' THEN
                RAISE EXCEPTION 'PRIVILEGE ESCALATION FAILED: Unexpected exception message on role escalation: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            END IF;
            v_role_escalate_blocked := true;
    END;

    IF NOT v_role_escalate_blocked THEN
        RAISE EXCEPTION 'PRIVILEGE ESCALATION FAILED: Member role escalation was not rejected by trigger!';
    END IF;
    IF EXISTS (SELECT 1 FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111103' AND role = 'owner') THEN
        RAISE EXCEPTION 'PRIVILEGE ESCALATION FAILED: Member escalated self to owner in database!';
    END IF;

    -- 5b. Member attempts tenant switching
    BEGIN
        UPDATE public.users SET tenant_id = v_t2 WHERE auth_id = '11111111-1111-1111-1111-111111111103';
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM NOT LIKE '%Non-management users may only update approved self-service profile fields%' THEN
                RAISE EXCEPTION 'TENANT HIJACK FAILED: Unexpected exception message on tenant switch: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            END IF;
            v_tenant_switch_blocked := true;
    END;

    IF NOT v_tenant_switch_blocked THEN
        RAISE EXCEPTION 'TENANT HIJACK FAILED: Member tenant switch was not rejected!';
    END IF;
    IF EXISTS (SELECT 1 FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111103' AND tenant_id = v_t2) THEN
        RAISE EXCEPTION 'TENANT HIJACK FAILED: Member switched tenant assignment in database!';
    END IF;

    -- 5c. Strict Update: Member attempts altering unapproved field (email)
    BEGIN
        UPDATE public.users SET email = 'hijacked@attacker.com' WHERE auth_id = '11111111-1111-1111-1111-111111111103';
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM NOT LIKE '%Non-management users may only update approved self-service profile fields%' THEN
                RAISE EXCEPTION 'PROFILE TAMPER FAILED: Unexpected exception message on email change: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            END IF;
            v_email_tamper_blocked := true;
    END;

    IF NOT v_email_tamper_blocked THEN
        RAISE EXCEPTION 'PROFILE TAMPER FAILED: Email modification was not rejected!';
    END IF;
    IF EXISTS (SELECT 1 FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111103' AND email = 'hijacked@attacker.com') THEN
        RAISE EXCEPTION 'PROFILE TAMPER FAILED: Member email was modified in database!';
    END IF;

    -- 5d. Strict Update: Member attempts altering active status
    BEGIN
        UPDATE public.users SET is_active = false WHERE auth_id = '11111111-1111-1111-1111-111111111103';
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM NOT LIKE '%Non-management users may only update approved self-service profile fields%' THEN
                RAISE EXCEPTION 'PROFILE TAMPER FAILED: Unexpected exception message on is_active change: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            END IF;
            v_active_tamper_blocked := true;
    END;

    IF NOT v_active_tamper_blocked THEN
        RAISE EXCEPTION 'PROFILE TAMPER FAILED: Active status modification was not rejected!';
    END IF;
    IF EXISTS (SELECT 1 FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111103' AND is_active = false) THEN
        RAISE EXCEPTION 'PROFILE TAMPER FAILED: Member deactivated account in database!';
    END IF;

    -- 5e. Positive check: Member updates permitted self-service field (full_name)
    UPDATE public.users SET full_name = 'Alpha Member Renamed' WHERE auth_id = '11111111-1111-1111-1111-111111111103';
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = '11111111-1111-1111-1111-111111111103' AND full_name = 'Alpha Member Renamed') THEN
        RAISE EXCEPTION 'SELF-SERVICE FAILED: Permitted name change on users was rejected!';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST 6: MEMBER FINANCIAL LEDGER OWNERSHIP
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111103';

DO $$
DECLARE
    v_my_payments INT;
    v_peer_payments INT;
    v_my_member_id UUID;
BEGIN
    SELECT id INTO v_my_member_id FROM public.members WHERE user_id = public.get_current_profile_id();

    SELECT count(*) INTO v_my_payments FROM public.payments WHERE member_id = v_my_member_id;
    SELECT count(*) INTO v_peer_payments FROM public.payments WHERE member_id != v_my_member_id;

    IF v_my_payments = 0 THEN RAISE EXCEPTION 'PAYMENT ACCESS FAILED: Member cannot view their own payments!'; END IF;
    IF v_peer_payments > 0 THEN RAISE EXCEPTION 'PAYMENT LEAK FAILED: Member leaked % peer payments!', v_peer_payments; END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TEST 7: REGISTRATION RPC ANTI-ABUSE & SLUG COLLISION HANDLING
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111101';

DO $$
DECLARE
    v_re_reg_blocked BOOLEAN := false;
BEGIN
    -- Existing registered owner cannot register another tenant
    BEGIN
        PERFORM public.register_gym_owner('Rogue Duplicate Gym', 'rogue-slug', '+91 98888 77777');
    EXCEPTION
        WHEN raise_exception THEN
            IF SQLERRM NOT LIKE '%already associated with registered tenant%' THEN
                RAISE EXCEPTION 'REGISTRATION RPC FAILED: Unexpected exception message on duplicate registration: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
            END IF;
            v_re_reg_blocked := true;
    END;

    IF NOT v_re_reg_blocked THEN
        RAISE EXCEPTION 'REGISTRATION RPC FAILED: Existing owner registered duplicate tenant without error!';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- ALWAYS ROLL BACK: ZERO RESIDUAL TEST DATA IN DATABASE
-- ----------------------------------------------------------------------------
ROLLBACK;
