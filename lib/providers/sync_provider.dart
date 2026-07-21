import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final DatabaseService _db = DatabaseService();
  VoidCallback? onSyncComplete;

  bool _isSyncEnabled = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncError;
  String? _appKey;

  bool get isSyncEnabled => _isSyncEnabled;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  String? get appKey => _appKey;
  bool get isAuthenticated => _isAuthenticated;

  bool _isAuthenticated = false;

  Future<void> init() async {
    _appKey = await _syncService.getAppKey();
    _isAuthenticated = await _syncService.isAuthenticated;
    final prefs = await SharedPreferences.getInstance();
    _isSyncEnabled = prefs.getBool('sync_enabled') ?? false;
    final lastSync = prefs.getString('last_sync_time');
    if (lastSync != null) {
      _lastSyncTime = DateTime.parse(lastSync);
    }
    notifyListeners();

    if (_isSyncEnabled && _isAuthenticated) {
      autoSync();
    }
  }

  String getAuthUrl(String appKey) {
    return _syncService.getAuthUrl(appKey);
  }

  Future<void> openAuthUrl(String appKey) async {
    _syncError = null;
    notifyListeners();
    await _syncService.authenticate(appKey);
  }

  Future<void> submitAuthCode(String appKey, String code) async {
    try {
      _syncError = null;
      notifyListeners();

      await _syncService.exchangeCodeAndSave(appKey, code);
      _appKey = appKey;
      _isSyncEnabled = true;
      _isAuthenticated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_enabled', true);
      await prefs.setString('dropbox_app_key', appKey);

      notifyListeners();
      await fullSync();
    } catch (e) {
      _syncError = e is DioException
          ? 'Auth failed: ${e.response?.data ?? e.message}'
          : 'Auth failed: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> disableSync() async {
    _isSyncEnabled = false;
    _isAuthenticated = false;
    _appKey = null;
    _syncError = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_enabled', false);
    await _syncService.logout();

    notifyListeners();
  }

  Future<void> fullSync() async {
    if (!_isSyncEnabled || !_isAuthenticated || _isSyncing) return;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final dataPath = await _db.dataDirectory;
      final mediaDir = '$dataPath/media';
      await _syncService.fullSync('$dataPath/journal_data.json', mediaDir);
      _lastSyncTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());
      onSyncComplete?.call();
    } catch (e) {
      _syncError = e is DioException
          ? 'Sync failed: ${e.response?.data ?? e.message}'
          : 'Sync failed: ${e.toString()}';
    }

    _isSyncing = false;
    notifyListeners();
  }

  Future<void> autoSync() async {
    if (!_isSyncEnabled || !_isAuthenticated) return;
    await fullSync();
  }

  Future<void> syncNow() async {
    await fullSync();
  }

  Future<void> resetCloud() async {
    _syncError = null;
    _isSyncing = true;
    notifyListeners();
    try {
      await _syncService.deleteAllRemote();
      _lastSyncTime = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_time');
    } catch (e) {
      _syncError = e is DioException
          ? 'Reset failed: ${e.response?.data ?? e.message}'
          : 'Reset failed: ${e.toString()}';
    }
    _isSyncing = false;
    notifyListeners();
  }
}
