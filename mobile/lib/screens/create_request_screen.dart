import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});
  @override State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final api = SupabaseService();
  final desc = TextEditingController();
  final address = TextEditingController();
  List<ServiceItem> services = [];
  String? serviceId, priority = 'medium';
  DateTime preferred = DateTime.now().add(const Duration(days: 1));
  bool loading = false;

  @override
  void initState() { super.initState(); loadServices(); }
  Future<void> loadServices() async {
    final s = await api.getServices();
    if (mounted) setState(() { services = s; serviceId = s.isEmpty ? null : s.first.id; });
  }

  Future<void> submit() async {
    if (serviceId == null || desc.text.trim().length < 5 || address.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields.')));
      return;
    }
    setState(() => loading = true);
    try {
      final r = await api.createRequest(
        serviceId: serviceId!, description: desc.text.trim(), preferredAt: preferred,
        address: address.text.trim(), priority: priority!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created ${r.code}')));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create request. Check your connection.')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: serviceId,
            decoration: const InputDecoration(labelText: 'Service type'),
            items: services.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => serviceId = v),
          ),
          const SizedBox(height: 14),
          TextField(controller: desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 14),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'high', child: Text('High')),
            ],
            onChanged: (v) => setState(() => priority = v),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              title: const Text('Preferred date/time'),
              subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(preferred)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: preferred, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                if (d == null || !context.mounted) return;
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(preferred));
                if (t != null) setState(() => preferred = DateTime(d.year,d.month,d.day,t.hour,t.minute));
              },
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Creating...' : 'Create Request')),
        ],
      ),
    );
  }
}
