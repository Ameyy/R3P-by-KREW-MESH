# R3P FITNESS — CANONICAL FINAL AUTHORIZATION MATRIX (V4 STRICT)

> **Security Baseline:** Cryptographic Session Identity (`auth.uid()`) + DB Trigger Enforcement  
> **Status:** Final Specification (Supersedes draft matrices)

---

## 1. Verified Role Hierarchy & Privilege Boundaries

```
[ super_admin ] (Platform Operations, Cross-Tenant SaaS Provisioning)
       │
       ▼
[ owner / manager / adm ] (Tenant Management: Full Tenant Control, Billing, Staff Compensation)
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
[ trainer / emp ]              [ front_desk / stf ]
(Assigned Workouts, Rosters,    (Member Lookups, Check-ins,
 Member Attendance)              Operational Schedules)
       │                                 │
       └────────────────┬────────────────┘
                        ▼
                [ member / mem ]
     (Self-Service Only: Own Profile, Invoices, QR Pass)
```

---

## 2. Table-by-Table Permission Matrix

| Table / View | Anonymous (`anon`) | Member (`member`) | Trainer (`trainer`) | Front Desk (`front_desk`) | Owner / Admin (`owner`) | Super Admin |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `public.tenants` | DENY | R (Tenant) | R (Tenant) | R (Tenant) | R + W (Tenant) | ALL |
| `public_tenant_directory` (View) | R (Active) | R (Active) | R (Active) | R (Active) | R (Active) | ALL |
| `public.users` | DENY | RW (Self only) | RW (Self only) | RW (Self only) | ALL (Tenant users) | ALL |
| `public.members` | DENY | R (Self only) | R + W (Tenant) | R + W (Tenant) | ALL (Tenant members) | ALL |
| `public.staff` | DENY | DENY | R (Self) + Clock-in | R (Self) + Clock-in | ALL (Full Salary/UPI) | ALL |
| `public_staff_roster` (View) | DENY | DENY | R (Tenant roster) | R (Tenant roster) | R (Tenant roster) | ALL |
| `public.membership_plans` | DENY* | R (Tenant plans) | R (Tenant plans) | R (Tenant plans) | ALL (Tenant plans) | ALL |
| `public.payments` | DENY | R (Self only) | DENY | R + W (Tenant payments) | ALL (Tenant payments) | ALL |
| `public.invoices` | DENY | R (Self only) | DENY | R (Tenant invoices) | ALL (Tenant invoices) | ALL |
| `public.attendance` | DENY | R (Self) + Check-in | R + W (Tenant) | R + W (Tenant) | ALL (Tenant attendance) | ALL |
| `public.branches` | DENY | R (Tenant) | R (Tenant) | R (Tenant) | ALL (Tenant branches) | ALL |
| `public.staff_shifts` | DENY | DENY | R (Tenant shifts) | R (Tenant shifts) | ALL (Tenant shifts) | ALL |
| `public.staff_leaves` | DENY | DENY | RW (Own requests) | RW (Own requests) | ALL (Review/Approve) | ALL |
| `public.promotional_offers` | DENY* | R (Tenant offers) | R (Tenant offers) | R (Tenant offers) | ALL (Tenant offers) | ALL |
| `public.facility_wifi_geofences`| DENY | DENY | R (Tenant wifi) | R (Tenant wifi) | ALL (Tenant wifi) | ALL |
| `public.audit_logs` | DENY | DENY | DENY | DENY | R (Tenant audit logs) | ALL |

*\*Public prospective members access active plans/branding through `public_tenant_directory` view.*

---

## 3. Defense-in-Depth Mechanisms

1. **Staff Salary Confidentiality (REST & Direct Queries):**
   - Direct `SELECT` on `public.staff` is restricted by RLS to management and individual self-read (`user_id = public.get_current_profile_id()`).
   - Peer rosters access `public_staff_roster`, which completely omits `base_salary_paise` and `upi`.
   - Routine staff clock-in updates are restricted: `trg_protect_staff_sensitive_fields` rejects any non-management mutation of compensation or role fields.
2. **Staff Update Ownership:**
   - Both `USING` and `WITH CHECK` enforce row ownership (`user_id = public.get_current_profile_id()`) for non-management staff. Staff can never modify another employee's records.
3. **Fail-Closed Client Security Gate:**
   - Client never renders protected modules from cached `localStorage` role tokens.
   - If Supabase Auth is missing, profile lookup fails, account is inactive (`is_active = false`), or role is unknown, the application fails closed to the login view.
