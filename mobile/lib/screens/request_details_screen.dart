import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../widgets/status_chip.dart';

class RequestDetailsScreen extends StatefulWidget {
  final ServiceRequest request;
  final Profile profile;
  const RequestDetailsScreen({super.key, required this.request, required this.profile});
  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late ServiceRequest r;
  final api = SupabaseService();
  final notes = TextEditingController();
  List<RequestHistoryItem> history = [];
  bool loadingHistory = true;

  @override
  void initState() {
    super.initState();
    r = widget.request;
    notes.text = r.notes ?? '';
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final h = await api.getRequestHistory(r.id);
      if (!mounted) return;
      setState(() {
        history = h;
        loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingHistory = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() {});
    try {
      await api.updateRequestStatus(r.id, status, note: notes.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Request updated: ${status.replaceAll('_', ' ')}.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: ${_friendly(e)}')));
    }
  }

  Future<void> _saveNotes() async {
    try {
      await api.updateRequestStatus(r.id, r.status, note: notes.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Notes saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save notes: ${_friendly(e)}')));
    }
  }

  String _friendly(Object error) {
    final s = error.toString();
    if (s.contains('transit')) return 'Illegal status change.';
    if (s.contains('only update requests assigned')) return 'You can only update your assigned requests.';
    if (s.contains('only update your own')) return 'You can only update your own requests.';
    if (s.contains('customers may only cancel')) return 'Customers can only cancel requests.';
    if (s.contains('no longer be cancelled')) return 'This request can no longer be cancelled.';
    return 'Please try again.';
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(r.serviceName, style: Theme.of(context).textTheme.titleLarge)),
              StatusChip(status: r.status),
            ],
          ),
          if (r.customerName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Customer: ${r.customerName}',
                  style: TextStyle(color: Colors.grey.shade700)),
            ),
          const SizedBox(height: 18),
          _item('Description', r.description),
          _item('Address', r.address),
          _item('Priority', r.priority.toUpperCase()),
          _item('Preferred', DateFormat('dd MMM yyyy, hh:mm a').format(r.preferredAt.toLocal())),
          if (r.notes?.isNotEmpty == true) _item('Progress notes', r.notes!),
          const SizedBox(height: 18),
          Text('Status history', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (loadingHistory)
            const Padding(
                padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator()))
          else if (history.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('No history recorded.'))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: history
                      .map((h) => _timelineRow(h))
                      .toList(),
                ),
              ),
            ),
          if (agent) ...[
            const SizedBox(height: 16),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Work notes'),
            ),
            const SizedBox(height: 12),
            if (r.status == 'assigned')
              FilledButton(onPressed: () => _updateStatus('accepted'), child: const Text('Accept')),
            if (r.status == 'accepted')
              FilledButton(onPressed: () => _updateStatus('in_progress'), child: const Text('Start Work')),
            if (r.status == 'in_progress')
              FilledButton(onPressed: () => _updateStatus('completed'), child: const Text('Mark Completed')),
            if (r.status != 'completed' && r.status != 'cancelled')
              OutlinedButton(onPressed: _saveNotes, child: const Text('Save Notes')),
          ],
          if (customer && (r.status == 'created' || r.status == 'assigned'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _updateStatus('cancelled'),
                child: const Text('Cancel Request'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineRow(RequestHistoryItem h) {
    final fmt = DateFormat('dd MMM, hh:mm a');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 10, color: Colors.indigo.shade300),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.oldStatus == null
                      ? h.newStatus.replaceAll('_', ' ').toUpperCase()
                      : '${h.oldStatus!.replaceAll('_', ' ').toUpperCase()} → ${h.newStatus.replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${h.changedByName} · ${fmt.format(h.createdAt.toLocal())}'
                  '${h.note.trim().isEmpty ? '' : ' · ${h.note.trim()}'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
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