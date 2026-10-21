# R3P FITNESS — ROLE-BY-ROLE AUTHORIZATION MATRIX

> **Security Standard:** Least Privilege & Verified Foreign-Key Authorization  
> **Target System:** PostgreSQL Row-Level Security (RLS)  
> **Key Principle:** Identity is derived exclusively from cryptographic `auth.uid()`, resolved against `public.users` within `public, pg_temp` search paths. Client-supplied headers, parameters, or localStorage tokens are untrusted.

---

## 1. Role Definitions

1. **Anonymous (`anon`)**: Unauthenticated public callers visiting landing pages, web manifests, or public schedules.
2. **Member (`member` / `mem`)**: Authenticated gym members with verified login accounts.
3. **Trainer (`trainer` / `emp`)**: Certified trainers managing assigned member workouts, class schedules, and check-ins.
4. **Front Desk (`front_desk` / `stf`)**: Operational front-desk personnel managing check-ins, member onboarding, and facility schedules.
5. **Gym Owner / Admin (`owner` / `adm` / `manager`)**: Gym business owners and club managers with full tenant administrative privileges.
6. **Platform Super Admin (`super_admin`)**: KREW/MESH SaaS operators managing multi-tenant infrastructure.

---

## 2. Table-by-Table Permission Grid

Legend:
- **ALL**: Full read, insert, update, and delete.
- **R**: Read-only access.
- **RO (Own)**: Read-only access restricted strictly to caller's own records.
- **RW (Own)**: Read and update caller's own records.
- **W (Tenant)**: Write/Update records strictly within caller's verified `tenant_id`.
- **R (Tenant)**: Read records strictly within caller's verified `tenant_id`.
- **DENY**: Zero access (enforced by RLS default deny).

| Table Name | Anonymous (`anon`) | Member (`member` / `mem`) | Trainer (`trainer` / `emp`) | Front Desk (`front_desk` / `stf`) | Owner / Admin (`owner` / `adm`) | Super Admin |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `public.tenants` | DENY* | R (Tenant) | R (Tenant) | R (Tenant) | R + W (Tenant) | ALL |
| `public_tenant_directory` (View) | R (Active) | R (Active) | R (Active) | R (Active) | R (Active) | ALL |
| `public.users` | DENY | RW (Own profile, no role edit) | RW (Own profile, no role edit) | RW (Own profile, no role edit) | R + W (Tenant staff & users) | ALL |
| `public.members` | DENY | RO (Own linked profile) | R + W (Tenant members) | R + W (Tenant members) | ALL (Tenant members) | ALL |
| `public.staff` | DENY | DENY | RO (Own record via view/table) | RO (Own record via view/table) | ALL (Tenant staff, full salary/UPI) | ALL |
| `public_staff_roster` (View) | DENY | R (Tenant roster) | R (Tenant roster) | R (Tenant roster) | R (Tenant roster) | ALL |
| `public.membership_plans` | R (Active) | R (Active) | R (Active) | R (Active) | ALL (Tenant plans) | ALL |
| `public.invoices` | DENY | RO (Own invoices) | DENY | R (Tenant invoices) | ALL (Tenant invoices) | ALL |
| `public.payments` | DENY | RO (Own payments) | DENY | R + W (Record tenant collections) | ALL (Tenant payments & refunds) | ALL |
| `public.attendance` | DENY | RO (Own logs) + Check-in | R + W (Tenant attendance) | R + W (Tenant attendance) | ALL (Tenant attendance) | ALL |
| `public.branches` | DENY | R (Tenant branches) | R (Tenant branches) | R (Tenant branches) | ALL (Tenant branches) | ALL |
| `public.staff_shifts` | DENY | DENY | R (Tenant shifts) | R (Tenant shifts) | ALL (Tenant shifts) | ALL |
| `public.staff_leaves` | DENY | DENY | RW (Own leave requests) | RW (Own leave requests) | ALL (Review & approve leaves) | ALL |
| `public.promotional_offers` | R (Active) | R (Active) | R (Active) | R (Active) | ALL (Tenant offers) | ALL |
| `public.facility_wifi_geofences`| DENY | DENY | R (Tenant geofences) | R (Tenant geofences) | ALL (Tenant geofences) | ALL |
| `public.audit_logs` | DENY | DENY | DENY | DENY | RO (Tenant audit logs) | ALL |

*\*Note: Anonymous users cannot query `public.tenants` directly (protects owner email, phone, and GST), but can query `public_tenant_directory` for gym name, logo, colors, and city.*

---

## 3. Critical Security Boundaries

### 3.1 Anti-Escalation Safeguard on `public.users`
Normal authenticated users can update their profile (e.g. name, avatar, emergency contact) but are strictly prevented from:
1. Modifying their `role` (preventing member -> owner escalation).
2. Modifying their `tenant_id` (preventing tenant switching/hijacking).
3. Modifying their `auth_id` (preventing identity impersonation).
4. Modifying their `is_active` status.

**Enforced by Policy:**
```sql
CREATE POLICY "Tenant users update policy" ON public.users
    FOR UPDATE TO authenticated
    USING (
        auth_id = auth.uid()
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    )
    WITH CHECK (
        (
            auth_id = auth.uid() 
            AND tenant_id = public.get_current_user_tenant_id() 
            AND role = (SELECT role FROM public.users WHERE auth_id = auth.uid())
        )
        OR (tenant_id = public.get_current_user_tenant_id() AND public.is_tenant_management())
    );
```

### 3.2 Sensitive Staff Financial Data Protection
Staff compensation fields (`base_salary_paise`, `upi_id`, `pan_number`) are stored in `public.staff`.
- **Management Role:** Has direct table SELECT access to calculate payroll and disburse funds.
- **Regular Staff & Trainers:** Can read their own record directly, but to see colleague schedules or check-in statuses, they must query `public_staff_roster` view which conceals financial columns.
- **Anonymous & Members:** Completely blocked from accessing `public.staff`.

### 3.3 Strict Account Linking & Backfill Policy
- **No Automatic Linking on Phone/Name Alone:** Telephony numbers and names are collision-prone and spoofable on unauthenticated forms.
- **Verified Linkage:** A legacy record with `user_id IS NULL` is only linked to an `auth.uid()` when:
  1. The user verifies ownership via Supabase Auth (e.g. SMS OTP or Email Magic Link).
  2. The gym owner or authorized manager confirms the identity linkage via admin dashboard, or a secure cryptographic invitation token is claimed.
