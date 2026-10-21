# R3P FITNESS — PREFLIGHT AUDIT, DEFECT RESOLUTION & REMAINING BLOCKERS

> **Status:** Review Only — Pending Staging Validation  
> **Environment Note:** Production database remains 100% untouched.

---

## 1. Resolution of Identified SQL Defects

| Defect / Mismatch | Prior State (V2) | Corrected State (V3) | Verification Status |
| :--- | :--- | :--- | :--- |
| **`payments.member_id` Schema Mismatch** | Migration and test suite assumed `payments.member_id` existed, creating invalid indexes and policies. | Identified that live `payments` only tracks `member_name`. Added additive nullable column `member_id UUID REFERENCES public.members(id) ON DELETE SET NULL` before any index/policy definition. | **RESOLVED IN SQL** (Requires staging run) |
| **Cross-Tenant Leak in `public_staff_roster`** | View queried `public.staff` without filtering by caller tenant, exposing staff across all gyms. | View now strictly enforces `WHERE s.tenant_id = public.get_current_user_tenant_id()`. | **RESOLVED IN SQL** (Requires staging run) |
| **Cross-Tenant Leaks in Plans & Offers** | Policies allowed any authenticated user to view plans/offers from all gyms via `USING (is_active = true)`. | Policies now strictly enforce `tenant_id = public.get_current_user_tenant_id() AND is_active = true`. | **RESOLVED IN SQL** (Requires staging run) |
| **Staff Salary Column Protection** | Relied purely on table-level RLS, which cannot prevent column tampering if a row is updatable. | Implemented `trg_protect_staff_sensitive_fields()` BEFORE UPDATE trigger to block non-management modification of `base_salary_paise`, `upi`, `role`, and `is_paid`. | **RESOLVED IN SQL** (Requires staging run) |
| **User Privilege & Tenant Switching** | Did not completely restrict management users to their own tenant or separate self-edits from administrative edits. | `trg_prevent_user_privilege_escalation()` strictly forbids self-updates to `role`, `tenant_id`, `auth_id`, or `is_active`. Management users are constrained strictly to rows where `tenant_id = caller_tenant_id`. | **RESOLVED IN SQL** (Requires staging run) |
| **`register_gym_owner()` Abuse** | Authenticated users could call RPC repeatedly to spawn unlimited tenant clusters. | Added strict guard checking `EXISTS (SELECT 1 FROM public.users WHERE auth_id = v_auth_uid)`, rejecting repeated invocations. | **RESOLVED IN SQL** (Requires staging run) |
| **Test Suite Fixtures & Coverage** | Test suite lacked fixture insertion for payments/plans, had no registration abuse test, and had no positive workflow tests. | Complete fixture suite added with two distinct tenants, positive member profile edit tests, and explicit registration anti-abuse checks. | **RESOLVED IN SQL** (Requires staging run) |

---

## 2. Unresolved Schema Assumptions (UNVERIFIED)

The following assumptions cannot be confirmed until read-access to the live Supabase catalog or an isolated staging dump is performed:
1. **[UNVERIFIED] Existing Foreign Key on `public.staff(user_id)`:** Live database may or may not already have a column named `user_id` on `staff`. Handled defensively via `ADD COLUMN IF NOT EXISTS`.
2. **[UNVERIFIED] Exact Extension Availability:** Script assumes PostgreSQL 13+ native `gen_random_uuid()` is available in the default search path.
3. **[UNVERIFIED] Live Triggers on `auth.users`:** If a Supabase Auth hook automatically creates rows in `public.users` on sign-up, `register_gym_owner` may conflict unless coordinated with that trigger.

---

## 3. Required Frontend Code Changes (Blockers to Production Cutover)

The migration is intentionally NOT marked production-ready until the following frontend changes in `js/main.js` and `js/supabase_client.js` are implemented and tested:

1. **Payment Ingestion (`main.js`):** Update `payments.insert()` to pass `member_id: targetMember.id` in addition to `member_name`, ensuring payments link to the member's account.
2. **Gym Registration (`main.js`):** Refactor `saveNewTenant()` to invoke `supabase.rpc('register_gym_owner', { ... })` instead of performing unauthenticated direct client inserts into `tenants` and `users`.
3. **Colleague Staff Schedules (`main.js`):** Point staff clock-in/roster widgets to the secure view `public_staff_roster` instead of `public.staff` to avoid access denials on confidential salary columns.
4. **Active Plans and Public Signup:** When an anonymous prospective member lands on a gym's custom slug or URL, the client must query `public_tenant_directory` to resolve the `tenant_id` before querying that tenant's active plans.
5. **Session Authorization:** Eliminate client-side trust of `localStorage.getItem("r3p_session_role")`. Authorize UI views based strictly on verified role data fetched from Supabase Auth and `public.users`.
