import 'dart:async';

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), _go);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _go() async {
    if (!mounted) return;
    Widget next = const AuthScreen();
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) next = const HomeScreen();
    } on Exception {
      // Cannot resolve the persisted session (e.g. offline/proxy). Fall back
      // to Login; the user can authenticate once connectivity is restored.
      next = const AuthScreen();
    }
    if (!mounted) return;
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