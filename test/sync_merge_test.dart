import 'package:ddx_journal/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _entry(int id, String updatedAt, {List<String> tags = const []}) {
  return {
    'id': id,
    'title': 'Entry $id',
    'content': '[{"insert":"Hello\\n"}]',
    'media_paths': '',
    'tags': tags.join(','),
    'date': '2026-01-01T00:00:00.000',
    'updated_at': updatedAt,
  };
}

Map<String, dynamic> _data({
  List<Map<String, dynamic>>? entries,
  List<int>? deletedEntryIds,
}) {
  return {
    'nextEntryId': 100,
    'nextTagId': 1,
    'entries': entries ?? [],
    'tags': <Map<String, dynamic>>[],
    'deletedEntryIds': ?deletedEntryIds,
  };
}

void main() {
  final sync = SyncService();

  group('SyncService.mergeData', () {
    test('returns empty structure when both sides are null', () {
      final merged = sync.mergeData(null, null);

      expect(merged['entries'], isEmpty);
      expect(merged['deletedEntryIds'], isEmpty);
    });

    test('returns remote when local is null', () {
      final remote = _data(entries: [_entry(1, '2026-01-01T10:00:00.000')]);

      final merged = sync.mergeData(null, remote);

      expect((merged['entries'] as List), hasLength(1));
    });

    test('returns local when remote is null', () {
      final local = _data(entries: [_entry(1, '2026-01-01T10:00:00.000')]);

      final merged = sync.mergeData(local, null);

      expect((merged['entries'] as List), hasLength(1));
    });

    test('keeps the newer version of a duplicated entry', () {
      final local = _data(entries: [_entry(1, '2026-01-01T09:00:00.000')]);
      final remote = _data(entries: [_entry(1, '2026-01-01T12:00:00.000')]);

      final merged = sync.mergeData(local, remote);
      final entries = merged['entries'] as List;

      expect(entries, hasLength(1));
      expect((entries.first as Map)['updated_at'], equals('2026-01-01T12:00:00.000'));
    });

    test('combines disjoint entries from both sides', () {
      final local = _data(entries: [_entry(1, '2026-01-01T10:00:00.000')]);
      final remote = _data(entries: [_entry(2, '2026-01-01T10:00:00.000')]);

      final merged = sync.mergeData(local, remote);

      expect((merged['entries'] as List), hasLength(2));
    });

    test('carries tags through merged entries', () {
      final local = _data(entries: [_entry(1, '2026-01-01T10:00:00.000', tags: ['work'])]);

      final merged = sync.mergeData(local, null);
      final entries = merged['entries'] as List;

      expect((entries.first as Map)['tags'], equals('work'));
    });

    test('removes an entry deleted on one side even if the other side is newer', () {
      final local = _data(
        entries: [_entry(1, '2026-01-01T10:00:00.000')],
        deletedEntryIds: [1],
      );
      final remote = _data(entries: [_entry(1, '2026-01-01T12:00:00.000')]);

      final merged = sync.mergeData(local, remote);

      expect(merged['entries'], isEmpty);
      expect(merged['deletedEntryIds'], equals([1]));
    });

    test('merges tombstones from both sides and filters all deleted entries', () {
      final local = _data(
        entries: [
          _entry(1, '2026-01-01T10:00:00.000'),
          _entry(2, '2026-01-01T10:00:00.000'),
        ],
        deletedEntryIds: [1],
      );
      final remote = _data(
        entries: [
          _entry(1, '2026-01-01T12:00:00.000'),
          _entry(3, '2026-01-01T10:00:00.000'),
        ],
        deletedEntryIds: [2],
      );

      final merged = sync.mergeData(local, remote);
      final entries = merged['entries'] as List;

      expect(entries.map((e) => (e as Map)['id']), equals([3]));
      expect(merged['deletedEntryIds'], equals([1, 2]));
    });
  });
}
