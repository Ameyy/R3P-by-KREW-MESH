import re

with open('/Users/dinesh/Desktop/r3p/js/main.js', 'r') as f:
    content = f.read()

# Inspect enter() function
old_enter_block = '''  role = selectedRole;
  localStorage.setItem("r3p_session_role", role);
  
  // 4. Access Control Gate: If user is Admin and subscription is NOT paid, redirect to Paywall Gate
  if(role === "adm" && !isSubscribed()) {
    showPaywallGate();
    return;
  }

  tab = {adm:"home", emp:"today", stf:"today", mem:"home"}[role] || "home";
  sub = null;
  fresh = 1;
  draw();'''

new_enter_block = '''  role = selectedRole;
  // Non-security UI preference cache (never trusted for server authorization)
  localStorage.setItem("r3p_session_role_preference", role);

  // If Supabase session is active, verify canonical identity from database profile
  if (window.R3PSupabase && window.R3PSupabase.client) {
    try {
      const { data: authUser } = await window.R3PSupabase.client.auth.getUser();
      if (authUser && authUser.user) {
        const { data: userProfile } = await window.R3PSupabase.client
          .from("users")
          .select("id, tenant_id, role, full_name")
          .eq("auth_id", authUser.user.id)
          .maybeSingle();

        if (userProfile) {
          // Harmonize canonical database role to frontend UI mode
          const roleMap = { owner: "adm", manager: "adm", super_admin: "adm", trainer: "emp", front_desk: "stf", member: "mem" };
          const verifiedRole = roleMap[userProfile.role] || userProfile.role;
          role = verifiedRole;
          window.R3PSupabase.tenantId = userProfile.tenant_id;
          console.log("🔒 [R3P Auth] Server-verified identity:", userProfile.role, "for tenant:", userProfile.tenant_id);
        }
      }
    } catch (e) {
      console.warn("[R3P Auth] Profile verification fallback:", e);
    }
  }
  
  // 4. Access Control Gate: If user is Admin and subscription is NOT paid, redirect to Paywall Gate
  if(role === "adm" && !isSubscribed()) {
    showPaywallGate();
    return;
  }

  tab = {adm:"home", emp:"today", stf:"today", mem:"home"}[role] || "home";
  sub = null;
  fresh = 1;
  draw();'''

if old_enter_block in content:
    content = content.replace(old_enter_block, new_enter_block)
    print("Successfully patched enter() with server-verified role checks.")
else:
    print("FAILED to find old_enter_block.")

# Also update launch initialization where savedRole is read
old_launch_role = '''const savedRole = localStorage.getItem("r3p_session_role");
if (savedRole && APP[savedRole]) {
  role = savedRole;
  authRole = savedRole;
  lr = savedRole;
  // If admin and not subscribed, show paywall gate
  if (role === "adm" && !isSubscribed()) {
    showPaywallGate();
  } else {
    tab = {adm:"home", emp:"today", stf:"today", mem:"home"}[role] || "home";
    sub = null;
    fresh = 1;
    draw();
  }
} else if (shouldShowOnboarding()) {'''

new_launch_role = '''// Resolve UI role from verified session preference or Supabase Auth session
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
} else if (shouldShowOnboarding()) {'''

if old_launch_role in content:
    content = content.replace(old_launch_role, new_launch_role)
    print("Successfully patched launch role initialization.")
else:
    print("FAILED to find old_launch_role.")

with open('/Users/dinesh/Desktop/r3p/js/main.js', 'w') as f:
    f.write(content)
