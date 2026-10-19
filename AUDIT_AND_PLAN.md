# R3P FITNESS — AUDIT, GAP ANALYSIS & PRODUCTION MASTER PLAN

**Platform:** R3P Fitness (KREW/MESH) — White-Label Gym Management ERP & SaaS
**Design Directive:** STRICT DESIGN LOCK. Zero unsolicited UI/layout changes. Preserve established Apple UI Design System & mobile layout.

---

## 1. Executive Audit Summary

| Component | Current State | Target Production State | Gap / Vulnerability |
| :--- | :--- | :--- | :--- |
| **Frontend Runtime** | Vanilla ES6 SPA in `/Users/dinesh/Desktop/r3p/js/main.js` + `theme.css` | High-performance mobile-first PWA with multi-tenant state and offline sync | In-memory mock arrays in `main.js` reset on refresh; `store.js` exists but is disconnected from `main.js`. |
| **Multi-Tenancy** | Hardcoded single gym data ("IronForge" / "R3P Fitness Pune") | Schema-level multi-tenancy with tenant UUIDs, per-gym branding, custom slugs, and RLS | No cross-tenant isolation enforcement; data is hardcoded in memory. |
| **Database & Schema** | No database connected; mock JSON | Supabase PostgreSQL schema with RLS, integer paise currencies, UTC timestamps | Missing formal schema migrations, foreign keys, non-negative checks, and RLS policies. |
| **Auth & Security** | Client-side role switcher (`adm`, `emp`, `mem`) with bypass credentials | Phone OTP / Supabase JWT Auth with database-enforced RBAC & session tokens | No real authentication or server verification; role elevation can be faked in client. |
| **Monetary Transactions** | Float/display strings (`₹1999`) in UI | 100% Integer Paise (`199900`), immutable payment ledger, sequential FY invoice IDs | Float precision risk; no reversing entries for refunds; no GST calculations. |
| **Attendance & QR** | Static SVG QR pass with no expiry | Signed rotating dynamic QR tokens (30–60s TTL), geofence validation, duplicate prevention | QR tokens can be screenshotted and shared; no automatic stale session checkout. |
| **White-Label & Super Admin**| Mock "Admin" view; no SaaS control console | Super Admin (KREW/MESH) console for gym tenant onboarding, license status, branding config | No platform management layer; missing grace period enforcement (members never blocked). |
| **Offline-First Storage** | None (in-memory arrays) | IndexedDB persistent queue with client UUID idempotency and background sync | Lost check-ins or workout logs on network drops. |

---

## 2. Implementation Checklist & Phase Roadmap

- [ ] **Phase 0: Architecture, Database Schema & Multi-Tenant Core**
  - [x] Full codebase audit and gap analysis (`AUDIT_AND_PLAN.md`)
  - [ ] Comprehensive Supabase PostgreSQL migration (`supabase_schema.sql`):
    - Multi-tenant tables: `tenants`, `branches`, `users`, `roles`, `permissions`, `members`, `plans`, `memberships`, `freezes`, `invoices`, `payments`, `attendance`, `pt_packages`, `pt_sessions`, `staff`, `payroll_runs`, `audit_logs`.
    - Integer paise for all money columns.
    - PostgreSQL Row-Level Security (RLS) policies for complete tenant isolation.
    - DB constraints (non-negative balances, sequential tenant FY invoice numbers, membership date checks).
  - [ ] Client Data Layer Bridge (`js/db.js`):
    - Connects `main.js` to IndexedDB + Supabase REST / local persistence.
    - Replaces volatile in-memory arrays with persistent, tenant-scoped stores.

- [ ] **Phase 1: Real Core Engine (Members, Plans, Invoices, Payments, Rotating QR)**
  - [ ] Member CRUD with search, filters, CSV export/import, health notes & emergency contacts.
  - [ ] Plan lifecycle: durations, joining fees, discounts, class credits, freeze allowances.
  - [ ] Sequential tenant-specific FY invoice generator (e.g., `R3P/26-27/0001`) with GST calculation.
  - [ ] Immutable payment ledger (UPI, Cash, Gateway) with reversing refund entries & daily cash closing.
  - [ ] Rotating cryptographic QR pass (30–60s expiry window) with scanner validator.

- [ ] **Phase 2: CRM, Retention Engine & Notification Routing**
  - [ ] Enquiry & lead pipeline with 1-tap WhatsApp deep-linking.
  - [ ] Nightly retention risk calculator (Low, Medium, High risk scoring).
  - [ ] Expiry alert automations (7, 3, 0 days) & quiet hours enforcement.

- [ ] **Phase 3: Trainer Workspace, Classes, PT Packages & Workout Logging**
  - [ ] PT package management with session deductions requiring confirmation.
  - [ ] Group class schedules with waitlist promotion.
  - [ ] Exercise library integration with personal record (PR) detection.

- [ ] **Phase 4: Staff Shifts, Attendance & Payroll Engine**
  - [ ] Staff clock-in/out with geofence verification.
  - [ ] Payroll calculator: base salary + PT commissions + incentives - deductions.
  - [ ] Read-only payroll lock after owner disbursement.

- [ ] **Phase 5: Super Admin Console (KREW/MESH SaaS Operations)**
  - [ ] Dedicated platform admin portal: tenant management, license status (`trial`, `active`, `past_due`, `suspended`).
  - [ ] Brand config generator (logo, colors, package ID, custom plans).
  - [ ] Member pass safeguard (members never blocked when gym owner license is past due).

- [ ] **Phase 6: PWA, Offline-Sync & Android/iOS Distribution Readiness**
  - [ ] Offline action queue in IndexedDB with replay idempotency.
  - [ ] Service worker caching strategy for PWA.
  - [ ] Android APK manifest & iOS Safari Add-to-Home-Screen setup.
