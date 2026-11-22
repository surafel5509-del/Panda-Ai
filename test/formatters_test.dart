import 'package:flutter_test/flutter_test.dart';
import 'package:panda_ai_studio/core/utils/formatters.dart';

void main() {
  group('Formatters.duration', () {
    test('handles null and zero', () {
      expect(Formatters.duration(null), '—');
      expect(Formatters.duration(Duration.zero), '—');
    });

    test('formats seconds and minutes', () {
      expect(Formatters.duration(const Duration(seconds: 7)), '7s');
      expect(Formatters.duration(const Duration(minutes: 1, seconds: 5)), '1:05');
      expect(Formatters.duration(const Duration(minutes: 12, seconds: 59)), '12:59');
    });
  });

  group('Formatters.fileSize', () {
    test('formats bytes, KB and MB', () {
      expect(Formatters.fileSize(512), '512 B');
      expect(Formatters.fileSize(2048), '2.0 KB');
      expect(Formatters.fileSize(3 * 1024 * 1024), '3.00 MB');
    });
  });

  group('Formatters.titleCase', () {
    test('splits on spaces, dashes and underscores', () {
      expect(Formatters.titleCase('natural'), 'Natural');
      expect(Formatters.titleCase('s2.1-pro-free'), 'S2.1 Pro Free');
      expect(Formatters.titleCase(''), '');
    });
  });

  group('Formatters.maskToken', () {
    test('masks long tokens keeping first/last 4', () {
      expect(Formatters.maskToken('abcd1234567890wxyz'), 'abcd••••••••wxyz');
    });

    test('fully masks short tokens and handles empty', () {
      expect(Formatters.maskToken('short'), '••••••••');
      expect(Formatters.maskToken(''), 'Not set');
      expect(Formatters.maskToken(null), 'Not set');
    });
  });
}
