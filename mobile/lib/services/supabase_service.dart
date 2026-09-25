import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final client = Supabase.instance.client;

  Future<Profile> getProfile() async {
    final data = await client.from('profiles').select().eq('id', client.auth.currentUser!.id).single();
    return Profile.fromMap(data);
  }

  Future<List<ServiceItem>> getServices() async {
    final data = await client.from('services').select().eq('active', true).order('name');
    return (data as List).map((e) => ServiceItem.fromMap(e)).toList();
  }

  Future<List<ServiceRequest>> getRequests({String? agentId}) async {
    var query = client.from('service_requests').select('*, services(name)');
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
    final service = await client.from('services').select().eq('id', serviceId).single();
    row['services'] = service;
    return ServiceRequest.fromMap(row);
  }

  Future<void> updateRequest(String id, Map<String, dynamic> changes) async {
    await client.from('service_requests').update(changes).eq('id', id);
  }

  Future<void> signOut() => client.auth.signOut();

  Future<void> sendReset(String email) => client.auth.resetPasswordForEmail(email);
}
