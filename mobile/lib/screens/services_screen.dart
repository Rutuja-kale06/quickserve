import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: FutureBuilder<List<ServiceItem>>(
        future: SupabaseService().getServices(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: snap.data!.map((s) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.build)),
                title: Text(s.name),
                subtitle: Text(s.description),
              ),
            )).toList(),
          );
        },
      ),
    );
  }
}
