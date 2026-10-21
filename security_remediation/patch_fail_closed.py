import re

with open('/Users/dinesh/Desktop/r3p/js/main.js', 'r') as f:
    content = f.read()

# 1. Replace the launch initialization so that it never renders protected UI without verifying Supabase Auth
old_init_block = '''// Resolve UI role from verified session preference or Supabase Auth session
const savedRole = localStorage.getItem("r3p_session_role_preference") || localStorage.getItem("r3p_session_role");
if (savedRole && APP[savedRole]) {
  role = savedRole;
  authRole = savedRole;
  lr = savedRole;
  
  // Asynchronously verify server authorization from Supabase session
  if (window.R3PSupabase && window.R3PSupabase.client) {
    window.R3PSupabase.client.auth.getUser().then(({ data }) => {
      if (data && data.user) {
        window.R3PSupabase.client
          .from("users")
          .select("id, tenant_id, role")
          .eq("auth_id", data.user.id)
          .maybeSingle()
          .then(({ data: profile }) => {
            if (profile) {
              const roleMap = { owner: "adm", manager: "adm", super_admin: "adm", trainer: "emp", front_desk: "stf", member: "mem" };
              const verified = roleMap[profile.role] || profile.role;
              if (role !== verified) {
                console.log("🔒 [R3P Auth] Correcting UI role to match verified profile:", verified);
                role = verified;
                window.R3PSupabase.tenantId = profile.tenant_id;
                if (typeof draw === "function") draw();
              }
            }
          });
      }
    });
  }

  // If admin and not subscribed, show paywall gate
  if (role === "adm" && !isSubscribed()) {
    showPaywallGate();
  } else {
    tab = {adm:"home", emp:"today", stf:"today", mem:"home"}[role] || "home";
    sub = null;
    fresh = 1;
    draw();
  }
} else if (shouldShowOnboarding()) {
  showOnboarding();
} else {
  login();
}'''

new_init_block = '''// ============================================================================
// FAIL-CLOSED AUTHENTICATION GATE
// Protected app modules are NEVER rendered from localStorage role values.
// Verification must succeed via Supabase Auth & public.users database profile.
// ============================================================================
async function initAppSecurityGate() {
  role = "";
  authRole = "adm";
  lr = "adm";

  if (window.R3PSupabase && window.R3PSupabase.client) {
    try {
      const { data: authData, error: authErr } = await window.R3PSupabase.client.auth.getUser();
      if (authErr || !authData || !authData.user) {
        console.log("🔒 [Security Gate] Unauthenticated session. Directing to login.");
        if (shouldShowOnboarding()) { showOnboarding(); } else { login(); }
        return;
      }

      // Verify active user profile and tenant assignment directly from public.users
      const { data: profile, error: profErr } = await window.R3PSupabase.client
        .from("users")
        .select("id, tenant_id, role, full_name, is_active")
        .eq("auth_id", authData.user.id)
        .maybeSingle();

      if (profErr || !profile) {
        console.warn("🔒 [Security Gate] Authenticated account lacks valid user profile. Directing to login.");
        toast("Account profile not found. Please log in again.");
        login();
        return;
      }

      if (!profile.is_active) {
        console.warn("🔒 [Security Gate] Account has been deactivated by administrator.");
        toast("Account has been deactivated. Contact gym management.");
        login();
        return;
      }

      // Resolve tenant and map canonical database role to frontend mode
      window.R3PSupabase.tenantId = profile.tenant_id;
      const roleMap = { owner: "adm", manager: "adm", super_admin: "adm", trainer: "emp", front_desk: "stf", member: "mem" };
      const verifiedRole = roleMap[profile.role];

      if (!verifiedRole || !APP[verifiedRole]) {
        console.warn("🔒 [Security Gate] Unknown canonical role:", profile.role);
        toast("Unauthorized role. Access denied.");
        login();
        return;
      }

      role = verifiedRole;
      authRole = verifiedRole;
      lr = verifiedRole;
      console.log("✅ [Security Gate] Access authorized for", verifiedRole, "Tenant:", profile.tenant_id);

      if (role === "adm" && !isSubscribed()) {
        showPaywallGate();
      } else {
        tab = {adm:"home", emp:"today", stf:"today", mem:"home"}[role] || "home";
        sub = null;
        fresh = 1;
        draw();
      }
      return;
    } catch (e) {
      console.warn("🔒 [Security Gate] Verification exception, failing closed:", e);
      login();
      return;
    }
  }

  // Fallback when Supabase client is offline/disconnected: Fail closed to login
  if (shouldShowOnboarding()) {
    showOnboarding();
  } else {
    login();
  }
}

initAppSecurityGate();'''

if old_init_block in content:
    content = content.replace(old_init_block, new_init_block)
    print("1. Successfully replaced launch gate with fail-closed initAppSecurityGate().")
else:
    print("1. FAILED to find old_init_block.")

with open('/Users/dinesh/Desktop/r3p/js/main.js', 'w') as f:
    f.write(content)
