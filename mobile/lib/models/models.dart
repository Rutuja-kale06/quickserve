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

class RequestHistoryItem {
  final int id;
  final String newStatus;
  final String? oldStatus;
  final String note;
  final String changedByName;
  final DateTime createdAt;

  RequestHistoryItem({
    required this.id,
    required this.newStatus,
    this.oldStatus,
    required this.note,
    required this.changedByName,
    required this.createdAt,
  });

  factory RequestHistoryItem.fromMap(Map<String, dynamic> m) {
    final changedBy = m['changed_by'];
    return RequestHistoryItem(
      id: m['id'],
      newStatus: m['new_status'] ?? 'created',
      oldStatus: m['old_status'],
      note: m['note'] ?? '',
      changedByName:
          changedBy is Map ? (changedBy['full_name'] ?? 'System') : 'System',
      createdAt: DateTime.parse(m['created_at']),
    );
  }
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
  final String customerName;

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
    this.customerName = '',
  });

  factory ServiceRequest.fromMap(Map<String, dynamic> m) {
    final service = m['services'];
    final customer = m['customer'];
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
      customerName: customer is Map ? (customer['full_name'] ?? '') : '',
    );
  }
}
