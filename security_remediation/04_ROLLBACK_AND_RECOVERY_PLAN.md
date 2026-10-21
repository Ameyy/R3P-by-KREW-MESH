# R3P FITNESS — DISASTER RECOVERY & FORWARD-FIX PROTOCOL

> **Status:** Revised Strict Recovery Plan  
> **Mandatory Security Rule:** In the event of an outage, rollback must NEVER re-apply `USING (true)` or unvalidated `tenant_id IS NOT NULL` policies.

---

## 1. Reality of Rollback & Limitations

A traditional "undo" SQL script that drops helper functions and reinstates permissive policies is **categorically unsafe**. If helper functions are dropped while other dependent policies exist, PostgreSQL will either abort with dependency errors (`cannot drop function ... because other objects depend on it`) or cascade-drop all dependent table protections, leaving the entire database completely exposed.

Furthermore, rolling back to the legacy schema re-introduces verified vulnerabilities where unauthenticated anonymous callers can read all member names, dues, staff salaries, and payment transactions.

Therefore, recovery is defined as:
1. **Primary Recovery: Hotfix Forward** (patching the specific syntax error or grant without breaking RLS).
2. **Secondary Recovery: Verified Point-In-Time Restore (PITR)** from an isolated pre-migration snapshot.
3. **Emergency Fallback: Safe Deny-First Lockdown** (never broad permissive access).

---

## 2. Recovery Scenarios & Procedures

### Scenario A: Migration Fails During Transaction
The hardening migration is wrapped in an atomic transaction (`BEGIN; ... COMMIT;`).
- If any statement in `20261021_final_reviewed_security_migration.sql` errors, PostgreSQL automatically rolls back the entire transaction.
- **Action:** No recovery script needed. The database remains in its pre-migration state.

### Scenario B: Unexpected Application Bug Post-Migration (e.g. Staff cannot record check-in)
Do NOT drop functions or re-enable `USING (true)`. Apply a targeted forward-patch.

#### Forward-Patch Protocol:
1. Identify the failing operation from browser network console / Supabase API logs (e.g., `403 Forbidden` on `public.attendance` during check-in).
2. Check if the authenticated session's `auth.uid()` exists in `public.users` with the expected tenant and role.
3. If a policy constraint is too restrictive, adjust ONLY that policy within the active transaction:
```sql
BEGIN;
DROP POLICY IF EXISTS "Tenant attendance insert policy" ON public.attendance;
CREATE POLICY "Tenant attendance insert policy" ON public.attendance
    FOR INSERT TO authenticated
    WITH CHECK (
        tenant_id = public.get_current_user_tenant_id()
        AND public.is_tenant_staff_or_trainer()
    );
COMMIT;
```

### Scenario C: Catastrophic Regression (Full Operational Blockage)
If production must be halted immediately:
1. **Never use `USING (true)` or `tenant_id IS NOT NULL`.**
2. Restore the pre-migration snapshot taken immediately prior to execution:
   ```bash
   # From human operator terminal using secured credentials:
   psql "$SUPABASE_DB_URL" -f pre_migration_backup.sql
   ```
3. If restoring a snapshot is not immediately possible, execute the **Emergency Lockdown Baseline**:
```sql
BEGIN;

-- Lock down to owner-only read while investigating:
DROP POLICY IF EXISTS "Tenant members select policy" ON public.members;
CREATE POLICY "Emergency lockdown members select" ON public.members
    FOR SELECT TO authenticated
    USING (
        tenant_id = (SELECT tenant_id FROM public.users WHERE auth_id = auth.uid() AND role IN ('owner', 'super_admin'))
    );

COMMIT;
```
