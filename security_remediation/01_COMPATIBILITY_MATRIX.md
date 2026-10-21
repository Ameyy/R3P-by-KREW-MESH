# R3P FITNESS — FRONTEND & DATABASE COMPATIBILITY MATRIX (RE-AUDITED)

> **Audit Date:** 2026-10-21  
> **Target Database:** Supabase PostgreSQL (`ylbrdxextihroqpvxbut.supabase.co`)  
> **Inspection Status:** Static & Architectural Inspection Complete  
> **Mandatory Policy:** Read-only inspection; NO production changes executed.

---

## 1. Verified Live Database Findings vs. Assumptions

### Verified Facts (Confirmed via Live Schema Inspection)
1. RLS is actively enabled on `members`, `staff`, `payments`, `invoices`, `attendance`, `users`, and `tenants`.
2. Roles `anon` and `authenticated` possess table-level SELECT and INSERT privileges.
3. Several live policies currently utilize `USING (true)`, allowing unauthenticated data exfiltration.
4. Existing write policies check basic field lengths but do not authenticate tenant ownership.
5. The function `public.rls_auto_enable()` is owned by `postgres`, is `SECURITY DEFINER`, has `search_path = pg_catalog`, and is called by the active event trigger `ensure_rls`.
6. Live database rows exist for tenants, members, staff, and plans that must be preserved.
7. Existing member and staff rows may have `user_id IS NULL`.
8. The frontend uses role codes (`adm`, `emp`, `stf`, `mem`) while the schema expects canonical roles (`owner`, `trainer`, `front_desk`, `member`).

### Explicitly Labeled Assumptions
- **[UNVERIFIED] Complete Live Policy Inventory:** Whether policies beyond the 32 in `supabase_schema.sql` exist on the live database is UNVERIFIED. (Addressed by dynamic catalog purge in Section 6 of the migration).
- **[UNVERIFIED] Exact Trigger Chain on `auth.users`:** Whether an automated webhook/trigger creates rows in `public.users` on sign-up is UNVERIFIED.
- **[UNVERIFIED] Exact Foreign Key Constraints on `members.user_id` & `staff.user_id`:** Live constraint definitions are UNVERIFIED. The migration uses `ADD COLUMN IF NOT EXISTS` defensively.

---

## 2. Table-by-Table Compatibility Matrix

*All runtime compatibility statuses are marked **UNVERIFIED until staging execution**.*

| Table Name | Live RLS Status | Frontend Operations (`main.js` / `client.js`) | Legacy Policy Vulnerability | Hardened RLS Policy Posture | Runtime Compatibility Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `public.tenants` | Enabled | `SELECT`, `INSERT` (signup) | `USING (true)` allows anon read of owner emails, phone numbers, and GST. | `SELECT` and `UPDATE` scoped to tenant owner via `get_current_user_tenant_id()`. Non-sensitive branding exposed via `public_tenant_directory` view. Direct client `INSERT` replaced by atomic `register_gym_owner` RPC. | **UNVERIFIED** (Requires frontend update to read branding from view & call RPC for signup) |
| `public.users` | Enabled | `INSERT` (signup), `SELECT` (profile) | `USING (true)` allows public read of all auth IDs, phones, and emails. Arbitrary role updates possible. | Self-read/update via `auth_id = auth.uid()`. Role and tenant updates blocked by trigger `trg_prevent_user_privilege_escalation`. Management can manage tenant users. Non-recursive. | **UNVERIFIED** (Requires session auth UID to match `users.auth_id`) |
| `public.members` | Enabled | `SELECT`, `UPDATE` (check-in, dues), `UPSERT` | `USING (true)` allows anon read of member names, dues, and phones. | Scoped to self (`user_id = public.users.id`) and tenant staff/trainers. No unauthenticated reads. Preserves rows with `user_id IS NULL`. | **UNVERIFIED** (Requires staff session to possess valid trainer/staff role in `users`) |
| `public.staff` | Enabled | `UPDATE` (clock-in, salary paid) | `USING (true)` exposes staff phones, salaries (`base_salary_paise`), and UPI IDs to anon. | Scoped to tenant management and individual self-read. General staff rosters query `public_staff_roster` view (excluding salaries/UPI). | **UNVERIFIED** (Requires frontend to use `public_staff_roster` for colleague views) |
| `public.payments` | Enabled | `INSERT` (UPI collections) | `USING (true)` exposes financial transactions, amounts, and UTRs to public. | Scoped to gym management and owning member (`member_id -> members.user_id`). Inserts restricted to verified tenant management. | **UNVERIFIED** (Requires payment recording to execute under authenticated management session) |
| `public.invoices` | Enabled | None (handled locally) | `USING (true)` exposes invoice totals and tax IDs to public. | Scoped to gym management and owning member. | **UNVERIFIED** (Future phase ready) |
| `public.attendance` | Enabled | `INSERT` (rotating QR scan log) | `USING (true)` exposes check-in timestamps and logs to anon. | Scoped to staff and owning member. Check-in inserts restricted to staff or verified member. | **UNVERIFIED** (Requires authenticated check-in session) |
| `public.membership_plans` | Enabled | `SELECT` (plans list) | `USING (true)` allows anon read. Write policies unrestricted across tenants. | Public read for `is_active = true` plans. Write restricted to authenticated tenant management. | **UNVERIFIED** (Public signup reads active plans) |
| `public.branches` | Enabled | None (handled in memory) | `USING (true)` allows public read. | Scoped to active tenant. Tenant management write permissions. | **UNVERIFIED** |
| `public.audit_logs` | Enabled | None | Unrestricted write allows log tampering. | Read restricted to tenant management. Append-only inserts for verified tenant. | **UNVERIFIED** |
| `public.facility_wifi_geofences` | Enabled | None | `USING (true)` exposes internal BSSID and network security infrastructure. | Read restricted to tenant staff and trainers. Writes restricted to management. | **UNVERIFIED** |
| `public.staff_shifts` | Enabled | None | `USING (true)` allows public read of staff working schedules. | Scoped to authenticated tenant staff and management. | **UNVERIFIED** |
| `public.staff_leaves` | Enabled | None | `USING (true)` allows public read of personal leave requests. | Scoped to tenant staff (own requests) and management approval. | **UNVERIFIED** |
| `public.promotional_offers` | Enabled | `INSERT` (offer creation) | `USING (true)` allows public read. Unrestricted writes. | Public read for `is_active = true`. Write restricted to authenticated tenant management. | **UNVERIFIED** (Requires owner auth for `saveNewOffer()`) |

---

## 3. Features Persisting Exclusively in Local Memory or LocalStorage

The following features in `js/main.js` currently have NO database persistence and rely strictly on volatile in-memory arrays:
1. **Lead Pipeline / CRM:** Array `leads` (stages: Trial Booked, Follow Up, Joined, Lost).
2. **Staff Tasks:** Array `tasks` (daily operational to-do items).
3. **Personal Training Roster:** Array `eclients` (PT clients, target weights, diet notes).
4. **Group Class Schedules:** Arrays `eclasses` and `mclasses` (class bookings and waitlists).
5. **Workout Logs:** Array `wk` (sets, reps, and exercise personal records).
6. **Announcements:** Array `ann` (bulletin board notices).
7. **Equipment Maintenance:** Array `eq` (service logs and status).
8. **Operational Expenses:** Array `exp` (daily cash expense ledger).
9. **Diet Engine:** Array `dietPlans` (macronutrient plans and meals).
