import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'request_details_screen.dart';
import 'create_request_screen.dart';
import 'services_screen.dart';
import 'profile_screen.dart';
import 'my_requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final api = SupabaseService();
  Profile? profile;
  List<ServiceRequest> requests = [];
  bool loading = true;

  // Agent view filter: all / active / completed.
  String agentFilter = 'Active';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await api.getProfile();
      final r = await api.getRequests(agentId: p.role == 'agent' ? p.id : null);
      if (!mounted) return;
      setState(() {
        profile = p;
        requests = r;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  List<ServiceRequest> get visibleRequests {
    if (agentFilter == 'Active') {
      return requests
          .where((r) => r.status != 'completed' && r.status != 'cancelled')
          .toList();
    }
    if (agentFilter == 'Completed') {
      return requests.where((r) => r.status == 'completed').toList();
    }
    return requests;
  }

  Future<void> _openRequest(ServiceRequest r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestDetailsScreen(request: r, profile: profile!)),
    );
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = profile!;
    final isAgent = p.role == 'agent';
    final recent = isAgent ? visibleRequests : requests.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${p.fullName.isEmpty ? 'there' : p.fullName.split(' ').first}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            icon: const Icon(Icons.person_outline),
          ),
        ],
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
                    Expanded(
                      child: Text(
                        isAgent
                            ? 'Your assigned work\nManage and update request status.'
                            : 'Need a service?\nCreate a request and track it here.',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!isAgent) ...[
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const CreateRequestScreen()));
                  load();
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Service Request'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MyRequestsScreen(profile: p))),
                      icon: const Icon(Icons.list_alt),
                      label: Text('My Requests (${requests.length})'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ServicesScreen())),
                    icon: const Icon(Icons.miscellaneous_services),
                    label: const Text('Services'),
                  ),
                ],
              ),
            ] else ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: 'Active', label: Text('Active')),
                  ButtonSegment(value: 'Completed', label: Text('Completed')),
                ],
                selected: {agentFilter},
                onSelectionChanged: (s) => setState(() => agentFilter = s.first),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              isAgent ? 'Assigned Requests' : 'Recent Requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Nothing here yet.')),
              )
            else
              ...recent.map((r) => Card(
                    child: ListTile(
                      title: Text('${r.code} · ${r.serviceName}'),
                      subtitle: Text(
                          '${r.status.replaceAll('_', ' ').toUpperCase()} · ${r.priority.toUpperCase()}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openRequest(r),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}