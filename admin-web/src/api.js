import { supabase } from './supabase';

const REQUEST_SELECT = `*, services(name),
  customer:profiles!service_requests_customer_id_fkey(full_name, phone),
  agent:profiles!service_requests_assigned_agent_id_fkey(full_name)`;

export async function fetchDashboard() {
  const [{ data: r }, { data: a }, { data: c }, { data: l }] = await Promise.all([
    supabase.from('service_requests').select(REQUEST_SELECT).order('created_at', { ascending: false }),
    supabase.from('profiles').select('*').eq('role', 'agent').order('full_name'),
    supabase.from('profiles').select('*').eq('role', 'customer').order('full_name'),
    supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(100),
  ]);
  return { requests: r ?? [], agents: a ?? [], customers: c ?? [], logs: l ?? [] };
}

export async function assignAgent(requestId, agentId) {
  const { error } = await supabase
    .from('service_requests')
    .update({ assigned_agent_id: agentId || null, status: agentId ? 'assigned' : 'created' })
    .eq('id', requestId);
  if (error) throw error;
}

export async function setStatus(requestId, status) {
  const { error } = await supabase.from('service_requests').update({ status }).eq('id', requestId);
  if (error) throw error;
}

export async function fetchHistory(requestId) {
  const { data, error } = await supabase
    .from('request_status_history')
    .select(
      'old_status, new_status, note, created_at, changed_by:profiles!request_status_history_changed_by_fkey(full_name)'
    )
    .eq('request_id', requestId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function logEvent(event, metadata = {}) {
  const { error } = await supabase.rpc('write_audit', { p_event: event, p_metadata: metadata });
  if (error) console.error('audit write failed:', error.message);
}

export { supabase };