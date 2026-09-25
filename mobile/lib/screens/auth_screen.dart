import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import '../services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool login = true, loading = false;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.length < 6) {
      _msg('Enter a valid email and a password of at least 6 characters.');
      return;
    }
    setState(() => loading = true);
    final api = SupabaseService();
    try {
      final auth = Supabase.instance.client.auth;
      if (login) {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
        await api.logEvent('LOGIN_SUCCESS', metadata: {'email': email.text.trim()});
      } else {
        await auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'full_name': name.text.trim(), 'phone': phone.text.trim()},
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on AuthException catch (e) {
      if (login) {
        await api.logEvent('LOGIN_FAILED',
            metadata: {'email': email.text.trim(), 'reason': e.message});
      }
      _msg(e.message);
    } catch (e) {
      _msg('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.home_repair_service, size: 56),
                    const SizedBox(height: 10),
                    const Text('QuickServe', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    const Text('Service requests made simple'),
                    const SizedBox(height: 28),
                    if (!login) ...[
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                      const SizedBox(height: 12),
                      TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                      const SizedBox(height: 12),
                    ],
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 12),
                    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : submit,
                        child: Text(loading ? 'Please wait...' : (login ? 'Login' : 'Create account')),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => login = !login),
                      child: Text(login ? 'New customer? Register' : 'Already have an account? Login'),
                    ),
                    if (login)
                      TextButton(
                        onPressed: () async {
                          if (email.text.trim().isEmpty) { _msg('Enter your email first.'); return; }
                          await Supabase.instance.client.auth.resetPasswordForEmail(email.text.trim());
                          _msg('Password reset email requested.');
                        },
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
