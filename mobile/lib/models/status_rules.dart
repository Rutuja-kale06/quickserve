/// Mirrors the PostgreSQL trigger `validate_status_transition()` in
/// supabase/001_schema.sql. The database remains authoritative; this Dart
/// copy is used for client-side UX hints and unit tests.
library;

const validTransitions = <String, List<String>>{
  'created': ['assigned', 'cancelled'],
  'assigned': ['accepted', 'cancelled'],
  'accepted': ['in_progress'],
  'in_progress': ['completed'],
};

bool isValidTransition(String from, String to) {
  if (from == to) return true; // notes-only updates
  final allowed = validTransitions[from];
  if (allowed == null) return false;
  return allowed.contains(to);
}