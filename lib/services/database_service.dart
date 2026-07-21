import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/journal_entry.dart';
import '../models/tag.dart';

class _AppData {
  int nextEntryId = 1;
  int nextTagId = 1;
  List<JournalEntry> entries = [];
  List<Tag> tags = [];
}

class DatabaseService {
  static DatabaseService? _instance;
  _AppData? _data;
  String? _filePath;

  DatabaseService._();

  factory DatabaseService() {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<String> get _path async {
    if (_filePath != null) return _filePath!;
    final dir = await getApplicationDocumentsDirectory();
    _filePath = p.join(dir.path, 'journal_data.json');
    return _filePath!;
  }

  Future<String> get dataDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<_AppData> _getData() async {
    if (_data != null) return _data!;
    final file = File(await _path);
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _data = _AppData()
        ..nextEntryId = json['nextEntryId'] as int? ?? 1
        ..nextTagId = json['nextTagId'] as int? ?? 1
        ..entries = (json['entries'] as List?)
                ?.map((e) => JournalEntry.fromMap(e as Map<String, dynamic>))
                .toList() ??
            []
        ..tags = (json['tags'] as List?)
                ?.map((e) => Tag.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];
    } else {
      _data = _AppData();
    }
    return _data!;
  }

  Future<void> _saveData() async {
    final data = await _getData();
    final file = File(await _path);
    final json = {
      'nextEntryId': data.nextEntryId,
      'nextTagId': data.nextTagId,
      'entries': data.entries.map((e) => e.toMap()).toList(),
      'tags': data.tags.map((t) => t.toMap()).toList(),
    };
    await file.writeAsString(jsonEncode(json));
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // --- Entries ---

  Future<bool> hasEntryForDate(DateTime date) async {
    final data = await _getData();
    final dateOnly = _dateOnly(date);
    return data.entries.any((e) =>
        _dateOnly(e.date).year == dateOnly.year &&
        _dateOnly(e.date).month == dateOnly.month &&
        _dateOnly(e.date).day == dateOnly.day);
  }

  Future<JournalEntry?> getEntryForDate(DateTime date) async {
    final data = await _getData();
    final dateOnly = _dateOnly(date);
    try {
      return data.entries.firstWhere((e) =>
          _dateOnly(e.date).year == dateOnly.year &&
          _dateOnly(e.date).month == dateOnly.month &&
          _dateOnly(e.date).day == dateOnly.day);
    } catch (_) {
      return null;
    }
  }

  Future<Set<DateTime>> getEntryDatesForMonth(int year, int month) async {
    final data = await _getData();
    final dates = <DateTime>{};
    for (final e in data.entries) {
      final d = e.date;
      if (d.year == year && d.month == month && e.hasTextContent) {
        dates.add(_dateOnly(d));
      }
    }
    return dates;
  }

  Future<int> insertEntry(JournalEntry entry) async {
    final data = await _getData();
    final id = data.nextEntryId++;
    final saved = entry.copyWith(id: id);
    data.entries.add(saved);
    await _saveData();
    return id;
  }

  Future<void> updateEntry(JournalEntry entry) async {
    final data = await _getData();
    final idx = data.entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      data.entries[idx] = entry;
      await _saveData();
    }
  }

  Future<void> deleteEntry(int id) async {
    final data = await _getData();
    data.entries.removeWhere((e) => e.id == id);
    await _saveData();
  }

  Future<List<JournalEntry>> getAllEntries() async {
    final data = await _getData();
    final sorted = List<JournalEntry>.from(data.entries)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  Future<List<JournalEntry>> searchEntries(String query) async {
    final data = await _getData();
    final q = query.toLowerCase();
    final results = data.entries
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.content.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  // --- Tags ---

  Future<int> insertTag(Tag tag) async {
    final data = await _getData();
    final id = data.nextTagId++;
    data.tags.add(tag.copyWith(id: id));
    await _saveData();
    return id;
  }

  Future<void> deleteTag(int id) async {
    final data = await _getData();
    data.tags.removeWhere((t) => t.id == id);
    await _saveData();
  }

  Future<List<Tag>> getAllTags() async {
    final data = await _getData();
    final sorted = List<Tag>.from(data.tags)
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  Future<List<String>> getTagsForEntry(int entryId) async {
    final data = await _getData();
    final entry = data.entries.where((e) => e.id == entryId);
    if (entry.isEmpty) return [];
    return entry.first.tags;
  }

  Future<void> setTagsForEntry(int entryId, List<String> tagNames) async {
    final data = await _getData();
    final idx = data.entries.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;

    data.entries[idx] = data.entries[idx].copyWith(tags: tagNames);

    for (final name in tagNames) {
      if (!data.tags.any((t) => t.name == name)) {
        final id = data.nextTagId++;
        data.tags.add(Tag(id: id, name: name, color: 0xFFCCC2DC));
      }
    }

    await _saveData();
  }

  Future<void> loadBulk(List<JournalEntry> entries, List<Tag> tags) async {
    _data = _AppData()
      ..entries = entries
      ..tags = tags
      ..nextEntryId = entries.isEmpty
          ? 1
          : entries.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1
      ..nextTagId = tags.isEmpty
          ? 1
          : tags.map((t) => t.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    await _saveData();
  }

  Future<void> resetAll() async {
    final file = File(await _path);
    if (await file.exists()) {
      await file.delete();
    }
    _data = _AppData();
  }
}
