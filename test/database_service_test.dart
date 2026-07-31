import 'dart:io';

import 'package:ddx_journal/models/journal_entry.dart';
import 'package:ddx_journal/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  JournalEntry entry({
    String content = '[{"insert":"Hello\\n"}]',
    List<String> tags = const [],
    List<String> mediaPaths = const [],
    DateTime? date,
  }) {
    return JournalEntry(
      title: 'Test',
      content: content,
      tags: tags,
      mediaPaths: mediaPaths,
      date: date ?? DateTime(2026, 7, 30),
      updatedAt: DateTime(2026, 7, 30),
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ddx_journal_test_');
    DatabaseService.setDataPathOverride(tempDir.path);
    db = DatabaseService();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DatabaseService entries', () {
    test('insert and retrieve by date', () async {
      final id = await db.insertEntry(entry());

      final found = await db.getEntryForDate(DateTime(2026, 7, 30));

      expect(found, isNotNull);
      expect(found!.id, equals(id));
    });

    test('tags persist across reload from disk', () async {
      final id = await db.insertEntry(entry());
      await db.setTagsForEntry(id, ['work', 'personal']);
      db.reloadFromDisk();

      final found = await db.getEntryForDate(DateTime(2026, 7, 30));
      expect(found!.tags, containsAll(['work', 'personal']));

      final tags = await db.getAllTags();
      expect(tags.map((t) => t.name), containsAll(['work', 'personal']));
    });

    test('media paths persist across reload from disk', () async {
      await db.insertEntry(entry(mediaPaths: ['/tmp/a.png']));
      db.reloadFromDisk();

      final found = await db.getEntryForDate(DateTime(2026, 7, 30));
      expect(found!.mediaPaths, equals(['/tmp/a.png']));
    });

    test('getEntryDatesForMonth only includes entries with text content', () async {
      await db.insertEntry(entry());
      await db.insertEntry(entry(
        content: '[{"insert":"\\n"}]',
        date: DateTime(2026, 7, 15),
      ));

      final dates = await db.getEntryDatesForMonth(2026, 7);

      expect(dates, hasLength(1));
    });
  });

  group('DatabaseService deletions', () {
    test('deleteEntry removes the entry and records a tombstone', () async {
      final id = await db.insertEntry(entry());
      await db.deleteEntry(id);

      expect(await db.getEntryForDate(DateTime(2026, 7, 30)), isNull);
      expect(await db.getDeletedEntryIds(), contains(id));
    });

    test('tombstones survive reload from disk', () async {
      final id = await db.insertEntry(entry());
      await db.deleteEntry(id);
      db.reloadFromDisk();

      expect(await db.getDeletedEntryIds(), contains(id));
    });
  });
}
