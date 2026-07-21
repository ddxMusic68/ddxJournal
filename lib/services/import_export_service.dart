import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../models/journal_entry.dart';
import '../models/tag.dart';
import 'database_service.dart';

class ImportExportService {
  final DatabaseService _db = DatabaseService();

  Future<String> exportData() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose export location',
    );
    if (dirPath == null) throw Exception('No directory selected');

    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final exportDir = Directory(p.join(dirPath, 'journal_export_$timestamp'));
    await exportDir.create(recursive: true);

    final dataDir = await _db.dataDirectory;
    final srcFile = File(p.join(dataDir, 'journal_data.json'));
    if (!await srcFile.exists()) throw Exception('No data to export');

    final data = jsonDecode(await srcFile.readAsString()) as Map<String, dynamic>;
    await File(p.join(exportDir.path, 'journal_data.json'))
        .writeAsString(jsonEncode(data));

    final entries = (data['entries'] as List?) ?? [];
    final mediaDir = Directory(p.join(exportDir.path, 'media'));
    final mediaCopied = <String>{};

    for (final e in entries) {
      final paths = (e['media_paths'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty) ??
          [];
      for (final path in paths) {
        if (mediaCopied.contains(path)) continue;
        final srcMedia = File(path);
        if (await srcMedia.exists()) {
          await mediaDir.create(recursive: true);
          await srcMedia.copy(p.join(mediaDir.path, p.basename(path)));
          mediaCopied.add(path);
        }
      }
    }

    return exportDir.path;
  }

  Future<(Map<String, dynamic>, String)?> pickAndReadImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select journal backup',
    );
    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path!;
    final file = File(filePath);
    if (!await file.exists()) return null;

    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final importDir = p.dirname(filePath);
    return (data, importDir);
  }

  Future<void> replaceAll(Map<String, dynamic> importedData, String importDir) async {
    final db = DatabaseService();
    await db.resetAll();

    final appDataDir = await db.dataDirectory;
    final appMediaDir = Directory(p.join(appDataDir, 'media'));

    final importedEntries = _parseEntries(importedData);
    final importedTags = _parseTags(importedData);

    final remappedEntries = <JournalEntry>[];
    for (final entry in importedEntries) {
      final remapped = await _remapMediaPaths(entry, importDir, appMediaDir);
      remappedEntries.add(remapped);
    }

    await db.loadBulk(remappedEntries, importedTags);
  }

  Future<void> mergeData(Map<String, dynamic> importedData, String importDir) async {
    final db = DatabaseService();
    final existingEntries = await db.getAllEntries();
    final existingTags = await db.getAllTags();

    final importedEntries = _parseEntries(importedData);
    final importedTags = _parseTags(importedData);

    final appDataDir = await db.dataDirectory;
    final appMediaDir = Directory(p.join(appDataDir, 'media'));

    final entryMap = <int, JournalEntry>{};
    for (final e in existingEntries) {
      entryMap[e.id!] = e;
    }

    for (var entry in importedEntries) {
      entry = await _remapMediaPaths(entry, importDir, appMediaDir);
      final existing = entryMap[entry.id];
      if (existing == null) {
        entryMap[entry.id!] = entry;
      } else {
        if (entry.updatedAt.isAfter(existing.updatedAt)) {
          entryMap[entry.id!] = entry;
        }
      }
    }

    final tagMap = <String, Tag>{};
    for (final t in existingTags) {
      tagMap[t.name] = t;
    }
    for (final t in importedTags) {
      if (!tagMap.containsKey(t.name)) {
        tagMap[t.name] = t;
      }
    }

    await db.loadBulk(entryMap.values.toList(), tagMap.values.toList());
  }

  List<JournalEntry> _parseEntries(Map<String, dynamic> data) {
    return (data['entries'] as List?)
            ?.map((e) => JournalEntry.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  List<Tag> _parseTags(Map<String, dynamic> data) {
    return (data['tags'] as List?)
            ?.map((e) => Tag.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<JournalEntry> _remapMediaPaths(
    JournalEntry entry,
    String importDir,
    Directory appMediaDir,
  ) async {
    if (entry.mediaPaths.isEmpty) return entry;

    final newPaths = <String>[];
    for (final oldPath in entry.mediaPaths) {
      final fileName = p.basename(oldPath);
      final srcFile = File(p.join(importDir, 'media', fileName));
      final destFile = File(p.join(appMediaDir.path, fileName));

      if (await srcFile.exists()) {
        if (!await appMediaDir.exists()) {
          await appMediaDir.create(recursive: true);
        }
        if (!await destFile.exists()) {
          await srcFile.copy(destFile.path);
        }
        newPaths.add(destFile.path);
      } else {
        newPaths.add(oldPath);
      }
    }

    return entry.copyWith(mediaPaths: newPaths);
  }
}
