with open('/Users/dinesh/Desktop/r3p/js/main.js', 'r') as f:
    content = f.read()

target = '''      if (rpcError) {
        console.warn("[R3P Auth] RPC register_gym_owner note:", rpcError.message);
      } else if (rpcData && rpcData.tenant_id) {
        window.R3PSupabase.tenantId = rpcData.tenant_id;
        console.log("✅ [R3P Auth] Registered tenant successfully:", rpcData.tenant_id);
      }'''

replacement = '''      if (rpcError || !rpcData || !rpcData.tenant_id) {
        const errMsg = rpcError ? rpcError.message : "Tenant provisioning failed.";
        console.error("🔒 [R3P Auth] Registration RPC failed:", errMsg);
        toast("Registration error: " + errMsg);
        if(submitBtn) { submitBtn.disabled = false; submitBtn.innerText = "Sign Up & Continue"; }
        return; // Abort: Never continue into application on failed registration
      }

      window.R3PSupabase.tenantId = rpcData.tenant_id;
      console.log("✅ [R3P Auth] Registered tenant successfully:", rpcData.tenant_id);'''

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/dinesh/Desktop/r3p/js/main.js', 'w') as f:
        f.write(content)
    print("Successfully patched handleRegister to abort on RPC error.")
else:
    print("FAILED to find target in main.js.")
