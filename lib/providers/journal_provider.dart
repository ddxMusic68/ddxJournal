import 'package:flutter/foundation.dart';
import '../models/journal_entry.dart';
import '../services/database_service.dart';

class JournalProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<JournalEntry> _entries = [];
  bool _isLoading = false;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Set<DateTime> _entryDates = {};

  List<JournalEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  DateTime get selectedMonth => _selectedMonth;
  Set<DateTime> get entryDates => _entryDates;

  Future<void> loadMonth(int year, int month) async {
    _selectedMonth = DateTime(year, month);
    _isLoading = true;
    notifyListeners();
    _entryDates = await _db.getEntryDatesForMonth(year, month);
    _isLoading = false;
    notifyListeners();
  }

  void previousMonth() {
    final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    loadMonth(prev.year, prev.month);
  }

  void nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    loadMonth(next.year, next.month);
  }

  bool hasEntryForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _entryDates.any((d) =>
        d.year == dateOnly.year &&
        d.month == dateOnly.month &&
        d.day == dateOnly.day);
  }

  Future<JournalEntry?> getEntryForDate(DateTime date) async {
    return await _db.getEntryForDate(date);
  }

  Future<bool> canCreateEntryForDate(DateTime date) async {
    return !(await _db.hasEntryForDate(date));
  }

  Future<void> addEntry(JournalEntry entry) async {
    final id = await _db.insertEntry(entry);
    final saved = entry.copyWith(id: id);
    await _db.setTagsForEntry(id, entry.tags);
    _entries.insert(0, saved);
    await loadMonth(_selectedMonth.year, _selectedMonth.month);
    notifyListeners();
  }

  Future<void> updateEntry(JournalEntry entry) async {
    await _db.updateEntry(entry);
    await _db.setTagsForEntry(entry.id!, entry.tags);
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
    }
    await loadMonth(_selectedMonth.year, _selectedMonth.month);
    notifyListeners();
  }

  Future<void> deleteEntry(int id) async {
    await _db.deleteEntry(id);
    _entries.removeWhere((e) => e.id == id);
    await loadMonth(_selectedMonth.year, _selectedMonth.month);
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await loadMonth(_selectedMonth.year, _selectedMonth.month);
      return;
    }
    _isLoading = true;
    notifyListeners();
    _entries = await _db.searchEntries(query);
    _isLoading = false;
    notifyListeners();
  }
}
