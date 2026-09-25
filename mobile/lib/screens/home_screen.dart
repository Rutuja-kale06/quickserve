import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'request_details_screen.dart';
import 'create_request_screen.dart';
import 'services_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final api = SupabaseService();
  Profile? profile;
  List<ServiceRequest> requests = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final p = await api.getProfile();
      final r = await api.getRequests(agentId: p.role == 'agent' ? p.id : null);
      if (mounted) setState(() { profile = p; requests = r; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p = profile!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${p.fullName.isEmpty ? 'there' : p.fullName.split(' ').first}'),
        actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())), icon: const Icon(Icons.person_outline))],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 28, child: Icon(Icons.home_repair_service)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(
                      p.role == 'agent' ? 'Assigned work' : 'Need a service?\\nCreate a request and track it here.',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (p.role == 'customer')
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRequestScreen()));
                  load();
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Service Request'),
              ),
            if (p.role == 'customer') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen())),
                icon: const Icon(Icons.miscellaneous_services),
                label: const Text('Browse Services'),
              ),
            ],
            const SizedBox(height: 22),
            Text(p.role == 'agent' ? 'Assigned Requests' : 'My Requests', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (requests.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No requests yet.')))
            else
              ...requests.map((r) => Card(
                child: ListTile(
                  title: Text('${r.code} • ${r.serviceName}'),
                  subtitle: Text('${r.status.replaceAll('_',' ')} • ${r.priority.toUpperCase()}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(request: r, profile: p)));
                    load();
                  },
                ),
              )),
          ],
        ),
      ),
    );
  }
}
