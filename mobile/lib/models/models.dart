class Profile {
  final String id;
  final String fullName;
  final String role;
  final String? phone;

  Profile({required this.id, required this.fullName, required this.role, this.phone});

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'],
    fullName: m['full_name'] ?? '',
    role: m['role'] ?? 'customer',
    phone: m['phone'],
  );
}

class ServiceItem {
  final String id;
  final String name;
  final String description;

  ServiceItem({required this.id, required this.name, required this.description});

  factory ServiceItem.fromMap(Map<String, dynamic> m) => ServiceItem(
    id: m['id'],
    name: m['name'],
    description: m['description'] ?? '',
  );
}

class ServiceRequest {
  final String id;
  final String code;
  final String serviceName;
  final String description;
  final String status;
  final String priority;
  final String address;
  final DateTime preferredAt;
  final String? notes;
  final String? agentId;

  ServiceRequest({
    required this.id,
    required this.code,
    required this.serviceName,
    required this.description,
    required this.status,
    required this.priority,
    required this.address,
    required this.preferredAt,
    this.notes,
    this.agentId,
  });

  factory ServiceRequest.fromMap(Map<String, dynamic> m) {
    final service = m['services'];
    return ServiceRequest(
      id: m['id'],
      code: m['request_code'],
      serviceName: service is Map ? (service['name'] ?? '') : '',
      description: m['description'] ?? '',
      status: m['status'] ?? 'created',
      priority: m['priority'] ?? 'medium',
      address: m['address'] ?? '',
      preferredAt: DateTime.parse(m['preferred_at']),
      notes: m['notes'],
      agentId: m['assigned_agent_id'],
    );
  }
}
