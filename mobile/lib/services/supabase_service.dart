import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final client = Supabase.instance.client;

  Future<Profile> getProfile() async {
    final data = await client
        .from('profiles')
        .select()
        .eq('id', client.auth.currentUser!.id)
        .single();
    return Profile.fromMap(data);
  }

  Future<List<ServiceItem>> getServices() async {
    final data =
        await client.from('services').select().eq('active', true).order('name');
    return (data as List).map((e) => ServiceItem.fromMap(e)).toList();
  }

  /// Lists requests the current user may see:
  ///  - customer: their own requests
  ///  - agent: requests assigned to them (pass agentId)
  Future<List<ServiceRequest>> getRequests({String? agentId}) async {
    var query = client
        .from('service_requests')
        .select('*, services(name), customer:profiles!service_requests_customer_id_fkey(full_name)');
    if (agentId != null) {
      query = query.eq('assigned_agent_id', agentId);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => ServiceRequest.fromMap(e)).toList();
  }

  Future<ServiceRequest> createRequest({
    required String serviceId,
    required String description,
    required DateTime preferredAt,
    required String address,
    required String priority,
  }) async {
    final data = await client.rpc('create_request', params: {
      'p_service_id': serviceId,
      'p_description': description,
      'p_preferred_at': preferredAt.toUtc().toIso8601String(),
      'p_address': address,
      'p_priority': priority,
    });
    final row = Map<String, dynamic>.from(data as Map);
    final service =
        await client.from('services').select().eq('id', serviceId).single();
    row['services'] = service;
    return ServiceRequest.fromMap(row);
  }

  /// Routed through the SECURITY DEFINER RPC: enforces ownership, role rules
  /// and lifecycle transitions server-side and writes the audit trail.
  Future<void> updateRequestStatus(
    String id,
    String newStatus, {
    String note = '',
  }) async {
    await client.rpc('update_request_status', params: {
      'p_request_id': id,
      'p_new_status': newStatus,
      'p_note': note,
    });
  }

  Future<List<RequestHistoryItem>> getRequestHistory(String requestId) async {
    final data = await client
        .from('request_status_history')
        .select(
            'id, old_status, new_status, note, created_at, changed_by:profiles!request_status_history_changed_by_fkey(full_name)')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => RequestHistoryItem.fromMap(e)).toList();
  }

  /// Lightweight application-level audit for auth/authorisation events.
  /// Server-side RPC enforces the allowed event list.
  Future<void> logEvent(String event, {Map<String, dynamic>? metadata}) async {
    await client.rpc('write_audit', params: {
      'p_event': event,
      'p_metadata': metadata ?? {},
    });
  }

  Future<void> signOut() => client.auth.signOut();

  Future<void> sendReset(String email) =>
      client.auth.resetPasswordForEmail(email);
}