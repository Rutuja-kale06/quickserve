import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// Branded splash shown on cold start while the persisted Supabase session is
/// resolved, then it routes to Login or the role-aware Home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    final next = session == null ? const AuthScreen() : const HomeScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_repair_service,
                size: 72, color: Colors.indigo),
            const SizedBox(height: 14),
            const Text(
              'QuickServe',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Service requests made simple',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 36),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}