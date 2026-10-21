# R3P FITNESS — PRODUCTION DEPLOYMENT & VERIFICATION RUNBOOK (REVISED)

> **Mandate:** STRICTLY NO DEPLOYMENT BY AI ASSISTANT.  
> This runbook is a documented reference for authorized human engineering leads.  
> Zero API keys or secrets are stored in this document.

---

## 1. Pre-Deployment Phase (Backups & Staging)

### 1.1 Complete Database Backup
Before initiating any schema modifications, execute a full logical backup of the live Supabase database via the Supabase CLI or management dashboard using your secure administrative credentials:
```bash
# Export schema and live data to an isolated local directory
supabase db dump --project-ref "$SUPABASE_PROJECT_REF" --data-only > r3p_prod_data_backup_$(date +%Y%m%d_%H%M%S).sql
supabase db dump --project-ref "$SUPABASE_PROJECT_REF" --schema-only > r3p_prod_schema_backup_$(date +%Y%m%d_%H%M%S).sql
```
*Verify backup file size is non-zero and contains existing member and staff records.*

### 1.2 Staging Verification Run
1. Restore backup into an isolated Supabase staging environment.
2. Execute `security_remediation/20261021_final_reviewed_security_migration.sql` in staging.
3. Execute `security_remediation/03_SQL_SECURITY_TEST_SUITE.sql` inside the staging database.
4. Confirm all assertions pass without policy syntax errors, constraint violations, or infinite recursion.

---

## 2. Production Deployment Execution Phase

### Step 2.1: Preflight Health Check
Verify existing database rows and connectivity:
```sql
SELECT count(*) FROM public.tenants;
SELECT count(*) FROM public.members;
SELECT count(*) FROM public.staff;
```

### Step 2.2: Apply Hardening Migration in Single Transaction
Execute the reviewed SQL migration:
- Open Supabase SQL Editor.
- Load `security_remediation/20261021_final_reviewed_security_migration.sql`.
- Review the statements within an explicit transaction:
```sql
BEGIN;
-- Execute migration contents here
COMMIT;
```

---

## 3. Post-Deployment Production Verification

Run the following automated verification checks against the live production instance using client environment variables:

### Check 1: Anonymous Access Blocked (Public REST Endpoint)
```bash
curl -s -X GET "$SUPABASE_URL/rest/v1/members?select=*" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"
```
**Expected Output:** `[]` (Empty JSON array. Zero member records leaked).

### Check 2: Staff Salary Protection
```bash
curl -s -X GET "$SUPABASE_URL/rest/v1/staff?select=id,name,base_salary_paise" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"
```
**Expected Output:** `[]` (Empty JSON array. Zero salaries leaked).

### Check 3: Public Branding View Accessibility
```bash
curl -s -X GET "$SUPABASE_URL/rest/v1/public_tenant_directory?select=id,name,slug,city" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"
```
**Expected Output:** Valid JSON containing public gym branding data without sensitive contact or GST details.

---

## 4. Required Frontend Changes (Pre-Requisites for Complete End-to-End Operation)

Before the frontend is fully switched to the hardened database, the following client adjustments are required:
1. **Gym Signup (`main.js`):** Replace direct client `INSERT INTO tenants` and `INSERT INTO users` with a call to the RPC function `supabase.rpc('register_gym_owner', { ... })`.
2. **Public Branding (`main.js` / `supabase_client.js`):** Query `public_tenant_directory` instead of `public.tenants` for unauthenticated gym metadata.
3. **Staff Roster (`main.js`):** Colleague schedule displays should query `public_staff_roster` instead of `public.staff`.
4. **Session Verification (`main.js`):** Derive active user role and tenant strictly from `auth.session()` linked to `public.users`, completely deprecating unverified `localStorage.getItem("r3p_session_role")`.
5. **Account Linking Protocol:** Do not link accounts by phone number or name alone. Provide a verified OTP claim flow for members where `user_id IS NULL`.
