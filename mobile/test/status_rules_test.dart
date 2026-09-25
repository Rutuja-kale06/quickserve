import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/status_rules.dart';

void main() {
  group('Request lifecycle transitions (mirror of DB trigger)', () {
    test('legal transitions succeed', () {
      expect(isValidTransition('created', 'assigned'), isTrue);
      expect(isValidTransition('created', 'cancelled'), isTrue);
      expect(isValidTransition('assigned', 'accepted'), isTrue);
      expect(isValidTransition('assigned', 'cancelled'), isTrue);
      expect(isValidTransition('accepted', 'in_progress'), isTrue);
      expect(isValidTransition('in_progress', 'completed'), isTrue);
    });

    test('notes-only updates (same status) are allowed', () {
      expect(isValidTransition('in_progress', 'in_progress'), isTrue);
      expect(isValidTransition('completed', 'completed'), isTrue);
    });

    test('illegal transitions are rejected', () {
      expect(isValidTransition('created', 'completed'), isFalse);
      expect(isValidTransition('created', 'in_progress'), isFalse);
      expect(isValidTransition('accepted', 'completed'), isFalse);
      expect(isValidTransition('accepted', 'cancelled'), isFalse);
      expect(isValidTransition('completed', 'in_progress'), isFalse);
      expect(isValidTransition('cancelled', 'created'), isFalse);
      expect(isValidTransition('cancelled', 'assigned'), isFalse);
    });

    test('terminal states have no outgoing edges', () {
      expect(validTransitions['completed'], isNull);
      expect(validTransitions['cancelled'], isNull);
    });
  });
}