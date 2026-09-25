import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../widgets/status_chip.dart';

class RequestDetailsScreen extends StatefulWidget {
  final ServiceRequest request;
  final Profile profile;
  const RequestDetailsScreen({super.key, required this.request, required this.profile});
  @override State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late ServiceRequest r;
  final api = SupabaseService();
  final notes = TextEditingController();

  @override
  void initState() { super.initState(); r = widget.request; notes.text = r.notes ?? ''; }

  Future<void> update(Map<String,dynamic> changes) async {
    try {
      await api.updateRequest(r.id, changes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request updated.')));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.profile.role == 'agent';
    final customer = widget.profile.role == 'customer';
    return Scaffold(
      appBar: AppBar(title: Text(r.code)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(r.serviceName, style: Theme.of(context).textTheme.titleLarge), StatusChip(status: r.status)]),
          const SizedBox(height: 18),
          _item('Description', r.description),
          _item('Address', r.address),
          _item('Priority', r.priority.toUpperCase()),
          _item('Preferred', r.preferredAt.toLocal().toString()),
          _item('Notes', r.notes?.isEmpty == false ? r.notes! : 'No notes'),
          if (agent) ...[
            const SizedBox(height: 12),
            TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Work notes')),
            const SizedBox(height: 12),
            if (r.status == 'assigned') FilledButton(onPressed: () => update({'status':'accepted','notes':notes.text}), child: const Text('Accept')),
            if (r.status == 'accepted') FilledButton(onPressed: () => update({'status':'in_progress','notes':notes.text}), child: const Text('Start Work')),
            if (r.status == 'in_progress') FilledButton(onPressed: () => update({'status':'completed','notes':notes.text}), child: const Text('Mark Completed')),
            if (r.status != 'completed' && r.status != 'cancelled')
              OutlinedButton(onPressed: () => update({'notes':notes.text}), child: const Text('Save Notes')),
          ],
          if (customer && (r.status == 'created' || r.status == 'assigned'))
            OutlinedButton(
              onPressed: () => update({'status':'cancelled'}),
              child: const Text('Cancel Request'),
            ),
        ],
      ),
    );
  }

  Widget _item(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 3),
      Text(value),
    ]),
  );
}
