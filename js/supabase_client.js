/**
 * R3P Fitness — Supabase Client Connector & Cloud Synchronization
 * Connects browser frontend to your Supabase PostgreSQL cloud backend.
 * Fallbacks to offline IndexedDB/LocalStorage if cloud is offline or schema not yet deployed.
 */

(function(window) {
  'use strict';

  const SUPABASE_URL = 'https://ylbrdxextihroqpvxbut.supabase.co';
  const SUPABASE_ANON_KEY = 'sb_publishable_dSncHqWSDhePdee4X9vbfA_ZgvYkkcU';
  const DEFAULT_TENANT_ID = 'a0000000-0000-0000-0000-000000000001';

  let client = null;
  if (window.supabase && window.supabase.createClient) {
    client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true
      }
    });
    console.log('⚡ [R3P Supabase] Cloud Client Initialized successfully.');
  } else {
    console.warn('[R3P Supabase] Supabase JS SDK not loaded yet. Falling back to local db.');
  }

  window.R3PSupabase = {
    client: client,
    tenantId: DEFAULT_TENANT_ID,
    isCloudConnected: false,

    async testConnection() {
      if (!this.client) return false;
      try {
        const { data, error } = await this.client.from('tenants').select('id, name, slug').limit(1);
        if (error) {
          console.warn('[R3P Supabase] Cloud query pending schema creation:', error.message);
          this.isCloudConnected = false;
          return false;
        }
        this.isCloudConnected = true;
        console.log('✅ [R3P Supabase] Cloud Connected to Tenant:', data[0]?.name);
        return true;
      } catch (err) {
        this.isCloudConnected = false;
        return false;
      }
    },

    // Fetch members from Supabase with fallback to local DB
    async getMembers() {
      if (this.client) {
        try {
          const { data, error } = await this.client
            .from('members')
            .select('*')
            .eq('tenant_id', this.tenantId)
            .order('name');
          if (!error && data && data.length > 0) {
            return data.map(m => ({
              id: m.id,
              n: m.name,
              p: m.plan_name,
              i: m.is_checked_in ? 1 : 0,
              due: Math.round((m.due_amount_paise || 0) / 100),
              phone: m.phone,
              t: m.checked_in_at || ''
            }));
          }
        } catch (e) {
          console.warn('[R3P Supabase] getMembers error, falling back to local store:', e);
        }
      }
      return null;
    },

    // Update check-in status in Supabase Cloud
    async updateCheckIn(memberId, isCheckedIn, timeStr) {
      if (this.client) {
        try {
          await this.client
            .from('members')
            .update({
              is_checked_in: isCheckedIn,
              checked_in_at: timeStr,
              updated_at: new Date().toISOString()
            })
            .eq('id', memberId);

          if (isCheckedIn) {
            await this.client.from('attendance').insert([{
              tenant_id: this.tenantId,
              member_id: memberId,
              member_name: 'Member',
              check_in_at: new Date().toISOString(),
              method: 'qr_rotating',
              is_verified: true
            }]);
          }
        } catch (e) {
          console.warn('[R3P Supabase] updateCheckIn cloud sync pending:', e);
        }
      }
    }
  };

  // Run initial test
  setTimeout(() => {
    if (window.R3PSupabase.client) {
      window.R3PSupabase.testConnection();
    }
  }, 500);

})(window);
