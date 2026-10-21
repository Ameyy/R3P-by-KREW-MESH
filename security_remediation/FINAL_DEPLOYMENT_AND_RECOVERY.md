# R3P FITNESS — CANONICAL FINAL DEPLOYMENT & DISASTER RECOVERY PROTOCOL (V5)

> **Mandate:** Production Database Unchanged. Execution strictly restricted to authorized human engineering leads.  
> **Status:** Final Deployment Protocol (Supersedes draft versions)

---

## 1. Staging Validation Protocol (Mandatory Step 1)

Execute the migration and test suite against an isolated staging PostgreSQL database:

```bash
# 1. Connect to isolated staging environment and run migration
psql "$STAGING_DATABASE_URL" -f security_remediation/FINAL_SECURITY_MIGRATION.sql

# 2. Run automated test suite
psql "$STAGING_DATABASE_URL" -f security_remediation/FINAL_SECURITY_TEST_SUITE.sql
```

**Expected Test Output:**
- All 7 test sections execute cleanly.
- Tests assert specific exceptions (`raise_exception`, `insufficient_privilege`, `check_violation`).
- Transaction terminates with `ROLLBACK` to leave staging completely unaltered.

---

## 2. Production Deployment Sequence (Step 2)

### 2.1 Complete Logical Backup
```bash
# Export schema and live data to a timestamped backup directory using human credentials
supabase db dump --project-ref "$SUPABASE_PROJECT_REF" --data-only > prod_backup_data_$(date +%Y%m%d_%H%M%S).sql
supabase db dump --project-ref "$SUPABASE_PROJECT_REF" --schema-only > prod_backup_schema_$(date +%Y%m%d_%H%M%S).sql
```
*Verify backup files are non-empty and capture existing members, staff, and payments.*

### 2.2 Execution via Supabase SQL Editor
When applying through the Supabase Dashboard SQL Editor:
1. Open Supabase Dashboard -> **SQL Editor** -> New Query.
2. Open [FINAL_SECURITY_MIGRATION.sql](file:///Users/dinesh/Desktop/r3p/security_remediation/FINAL_SECURITY_MIGRATION.sql) in your local editor.
3. **Copy the entire text** of `FINAL_SECURITY_MIGRATION.sql` and paste it directly into the SQL Editor window (Note: do NOT use `\i` commands; `\i` is an interactive `psql` shell meta-command and is unsupported in web SQL editors).
4. Click **Run** to execute the script within its explicit `BEGIN; ... COMMIT;` transaction block.

---

## 3. Post-Deployment Verification Checklist

Using operator environment variables (zero hardcoded secrets):

1. **Anonymous Read Check:**
   ```bash
   curl -s -X GET "$SUPABASE_URL/rest/v1/members?select=*" \
     -H "apikey: $SUPABASE_ANON_KEY" \
     -H "Authorization: Bearer $SUPABASE_ANON_KEY"
   ```
   *Expected Output: `[]` (Empty array. Zero member records leaked).*

2. **Staff Direct Salary Check:**
   ```bash
   curl -s -X GET "$SUPABASE_URL/rest/v1/staff?select=id,name,base_salary_paise" \
     -H "apikey: $SUPABASE_ANON_KEY" \
     -H "Authorization: Bearer $SUPABASE_ANON_KEY"
   ```
   *Expected Output: `[]` (Empty array. Zero salary columns leaked).*

3. **Public Directory Check:**
   ```bash
   curl -s -X GET "$SUPABASE_URL/rest/v1/public_tenant_directory?select=id,name,slug,city" \
     -H "apikey: $SUPABASE_ANON_KEY" \
     -H "Authorization: Bearer $SUPABASE_ANON_KEY"
   ```
   *Expected Output: Valid JSON list of active gym branding attributes.*

---

## 4. Disaster Recovery & Forward-Fix Protocol

1. **Never Revert to `USING (true)` or `tenant_id IS NOT NULL`:**
   Re-enabling permissive policies re-introduces critical vulnerabilities.
2. **Transaction Failure:**
   If any command in `FINAL_SECURITY_MIGRATION.sql` fails, the `BEGIN ... COMMIT` block automatically aborts. The live database remains unaltered.
3. **Point-In-Time Restoration:**
   If a catastrophic operational stoppage occurs, restore the verified pre-migration backup via Supabase dashboard point-in-time restore tools.
