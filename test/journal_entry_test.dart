import 'package:ddx_journal/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalEntry serialization', () {
    test('toMap/fromMap round trip preserves all fields', () {
      final entry = JournalEntry(
        id: 3,
        title: 'My title',
        content: '[{"insert":"hello\\n"}]',
        mediaPaths: ['/a.png', '/b.jpg'],
        tags: ['work', 'personal'],
        date: DateTime(2026, 7, 30, 9, 15),
        updatedAt: DateTime(2026, 7, 30, 9, 30),
      );

      final restored = JournalEntry.fromMap(entry.toMap());

      expect(restored.id, equals(3));
      expect(restored.title, equals('My title'));
      expect(restored.content, equals('[{"insert":"hello\\n"}]'));
      expect(restored.mediaPaths, equals(['/a.png', '/b.jpg']));
      expect(restored.tags, equals(['work', 'personal']));
      expect(restored.date, equals(DateTime(2026, 7, 30, 9, 15)));
      expect(restored.updatedAt, equals(DateTime(2026, 7, 30, 9, 30)));
    });

    test('missing optional fields default to empty lists', () {
      final entry = JournalEntry.fromMap({
        'id': 1,
        'title': 'x',
        'content': 'y',
        'date': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });

      expect(entry.mediaPaths, isEmpty);
      expect(entry.tags, isEmpty);
    });

    test('empty tags and media survive round trip as empty lists', () {
      final entry = JournalEntry(
        id: 1,
        title: '',
        content: 'x',
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = JournalEntry.fromMap(entry.toMap());

      expect(restored.mediaPaths, isEmpty);
      expect(restored.tags, isEmpty);
    });
  });

  group('JournalEntry.hasTextContent', () {
    test('true for non-empty quill delta', () {
      final entry = JournalEntry(
        title: '',
        content: '[{"insert":"Hello world\\n"}]',
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(entry.hasTextContent, isTrue);
    });

    test('false for empty quill delta', () {
      final entry = JournalEntry(
        title: '',
        content: '[{"insert":"\\n"}]',
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(entry.hasTextContent, isFalse);
    });

    test('falls back to raw content when not JSON', () {
      final entry = JournalEntry(
        title: '',
        content: '  ',
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(entry.hasTextContent, isFalse);
    });
  });
}
