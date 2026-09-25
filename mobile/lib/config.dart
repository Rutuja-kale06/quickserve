class AppConfig {
  // Supabase project values.
  //
  // Defaults below point at the live demo project. To point the app at a
  // different project (or avoid committing keys), inject at build/run time:
  //   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jigyedeiyqkzdsbgnjwd.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ocLBpXok5z-pp3kXQrzmPw_fjObUwxq',
  );
}