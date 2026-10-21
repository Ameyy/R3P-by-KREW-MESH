with open('/Users/dinesh/Desktop/r3p/js/main.js', 'r') as f:
    content = f.read()

target = '''  // Live Cloud Synchronization with Supabase
  if(window.R3PSupabase && window.R3PSupabase.client) {
    if(isMem) {
      window.R3PSupabase.client.from("members")
        .update({ is_checked_in: !!x.i, checked_in_at: x.t, updated_at: new Date().toISOString() })
        .eq("name", x.n)
        .then(({error}) => {
          if(error) console.warn("[Supabase Sync] Member check-in update error:", error);
          else console.log("[Supabase Sync] Member check-in updated in cloud:", x.n, x.i);
        });
    } else {
      window.R3PSupabase.client.from("staff")
        .update({ is_clocked_in: !!x.i, clocked_in_at: x.t })
        .eq("name", x.n)
        .then(({error}) => {
          if(error) console.warn("[Supabase Sync] Staff check-in update error:", error);
          else console.log("[Supabase Sync] Staff check-in updated in cloud:", x.n, x.i);
        });
    }
  }'''

replacement = '''  // Live Cloud Synchronization with Supabase
  if(window.R3PSupabase && window.R3PSupabase.client) {
    if(isMem) {
      const memQuery = window.R3PSupabase.client.from("members")
        .update({ is_checked_in: !!x.i, checked_in_at: x.t, updated_at: new Date().toISOString() });
      if (x.id) {
        memQuery.eq("id", x.id);
      } else {
        memQuery.eq("name", x.n);
      }
      memQuery.then(({error}) => {
        if(error) console.warn("[Supabase Sync] Member check-in update error:", error);
        else console.log("[Supabase Sync] Member check-in updated in cloud:", x.n, x.i);
      });
    } else {
      // Staff attendance update: Only modifies clock-in status; never touches salary or role
      const staffQuery = window.R3PSupabase.client.from("staff")
        .update({ is_clocked_in: !!x.i, clocked_in_at: x.t });
      if (x.id) {
        staffQuery.eq("id", x.id);
      } else {
        staffQuery.eq("name", x.n);
      }
      staffQuery.then(({error}) => {
        if(error) console.warn("[Supabase Sync] Staff check-in update error:", error);
        else console.log("[Supabase Sync] Staff check-in updated in cloud:", x.n, x.i);
      });
    }
  }'''

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/dinesh/Desktop/r3p/js/main.js', 'w') as f:
        f.write(content)
    print("Successfully patched attendance synchronization.")
else:
    print("FAILED to find target block in main.js.")
