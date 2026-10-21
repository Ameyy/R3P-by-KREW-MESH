import re

with open('/Users/dinesh/Desktop/r3p/js/main.js', 'r') as f:
    content = f.read()

# 1. Update member sync on launch to populate m.id into existing members
old_member_sync = '''window.R3PSupabase.client.from("members").select("*").order("name").then(({data, error}) => {
    if (!error && data && data.length > 0) {
      data.forEach((m, idx) => {
        const existing = members.find(localM => localM.n === m.name);
        if (existing) {
          existing.i = m.is_checked_in ? 1 : 0;
          existing.t = m.checked_in_at || (m.is_checked_in ? "07:15 AM" : "");
          existing.p = m.plan_name || existing.p;
          existing.due = Math.round((m.due_amount_paise || 0) / 100);
        }
      });'''

new_member_sync = '''window.R3PSupabase.client.from("members").select("*").order("name").then(({data, error}) => {
    if (!error && data && data.length > 0) {
      data.forEach((m, idx) => {
        const existing = members.find(localM => localM.n === m.name);
        if (existing) {
          existing.id = m.id; // Store verified Supabase member UUID
          existing.i = m.is_checked_in ? 1 : 0;
          existing.t = m.checked_in_at || (m.is_checked_in ? "07:15 AM" : "");
          existing.p = m.plan_name || existing.p;
          existing.due = Math.round((m.due_amount_paise || 0) / 100);
        } else {
          // Add remote member to local state with verified id
          members.push({
            id: m.id,
            n: m.name,
            p: m.plan_name || "Pro",
            i: m.is_checked_in ? 1 : 0,
            due: Math.round((m.due_amount_paise || 0) / 100),
            phone: m.phone || "",
            t: m.checked_in_at || ""
          });
        }
      });'''

if old_member_sync in content:
    content = content.replace(old_member_sync, new_member_sync)
    print("1. Successfully patched member sync on launch to store member UUID.")
else:
    print("1. FAILED to find old_member_sync.")

# 2. Update payment insert to pass valid member_id
old_payment_insert = '''      const amountPaise = Math.round(p.amt * 100);
      window.R3PSupabase.client.from("payments").insert([{
        tenant_id: window.R3PSupabase.tenantId,
        member_name: targetMember.n,
        amount_paise: amountPaise,
        mode: "upi",
        reference_utr: utrRef,
        notes: "Membership collection via UPI"
      }]).then(({error}) => {'''

new_payment_insert = '''      const amountPaise = Math.round(p.amt * 100);
      const paymentPayload = {
        tenant_id: window.R3PSupabase.tenantId,
        member_name: targetMember.n,
        amount_paise: amountPaise,
        mode: "upi",
        reference_utr: utrRef,
        notes: "Membership collection via UPI"
      };
      if (targetMember.id) {
        paymentPayload.member_id = targetMember.id;
      }
      window.R3PSupabase.client.from("payments").insert([paymentPayload]).then(({error}) => {'''

if old_payment_insert in content:
    content = content.replace(old_payment_insert, new_payment_insert)
    print("2. Successfully patched payments insert to include member_id.")
else:
    print("2. FAILED to find old_payment_insert.")

# 3. Update handleRegister to use register_gym_owner RPC
old_reg_block = '''      // 2. Persist real tenant record into Supabase
      const tenantSlug = gymName.toLowerCase().replace(/[^a-z0-9]/g, "-").slice(0, 50) + "-" + Date.now().toString().slice(-4);
      const { data: tenantData, error: tenantError } = await window.R3PSupabase.client.from("tenants").insert([{
        name: gymName,
        slug: tenantSlug,
        owner_email: email,
        phone: phone,
        address: addr || "Main Club",
        city: "Pune",
        status: "active"
      }]).select();

      if (tenantError) {
        console.warn("[R3P Auth] Tenant record warning:", tenantError.message);
      }

      // 3. Persist user profile record into public.users
      const { error: userError } = await window.R3PSupabase.client.from("users").insert([{
        tenant_id: tenantData && tenantData[0] ? tenantData[0].id : window.R3PSupabase.tenantId,
        auth_id: authData?.user?.id || null,
        phone: phone,
        email: email,
        full_name: name,
        role: "owner"
      }]);
      if (userError) {
        console.warn("[R3P Auth] User profile insert notice:", userError.message);
      }'''

new_reg_block = '''      // 2. Atomic Registration via register_gym_owner() RPC
      const tenantSlug = gymName.toLowerCase().replace(/[^a-z0-9]/g, "-").slice(0, 50) + "-" + Date.now().toString().slice(-4);
      const { data: rpcData, error: rpcError } = await window.R3PSupabase.client.rpc("register_gym_owner", {
        p_gym_name: gymName,
        p_slug: tenantSlug,
        p_phone: phone,
        p_address: addr || "Main Club",
        p_city: "Pune",
        p_full_name: name
      });

      if (rpcError) {
        console.warn("[R3P Auth] RPC register_gym_owner note:", rpcError.message);
      } else if (rpcData && rpcData.tenant_id) {
        window.R3PSupabase.tenantId = rpcData.tenant_id;
        console.log("✅ [R3P Auth] Registered tenant successfully:", rpcData.tenant_id);
      }'''

if old_reg_block in content:
    content = content.replace(old_reg_block, new_reg_block)
    print("3. Successfully patched handleRegister to call register_gym_owner RPC.")
else:
    print("3. FAILED to find old_reg_block.")

with open('/Users/dinesh/Desktop/r3p/js/main.js', 'w') as f:
    f.write(content)
print("Finished writing patched main.js.")
