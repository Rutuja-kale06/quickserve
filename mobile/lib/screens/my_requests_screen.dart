import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'request_details_screen.dart';

/// Dedicated "My Requests" screen: the full history of the signed-in customer's
/// service requests with live status (role-aware list for agents).
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final api = SupabaseService();
  List<ServiceRequest> requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await api.getRequests(
        agentId: widget.profile.role == 'agent' ? widget.profile.id : null,
      );
      if (!mounted) return;
      setState(() {
        requests = r;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not load requests. Check your connection.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.role == 'agent'
            ? 'Assigned Requests'
            : 'My Requests'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('No requests yet.'))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: requests
                        .map((r) => Card(
                              child: ListTile(
                                title: Text('${r.code} · ${r.serviceName}'),
                                subtitle: Text(
                                    '${r.status.replaceAll('_', ' ').toUpperCase()} · ${r.priority.toUpperCase()}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RequestDetailsScreen(
                                          request: r, profile: widget.profile),
                                    ),
                                  );
                                  if (mounted) load();
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
    );
  }
}