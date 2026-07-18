import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class SyncService {
  static const String _accessTokenKey = 'dropbox_access_token';
  static const String _refreshTokenKey = 'dropbox_refresh_token';
  static const String _appKeyKey = 'dropbox_app_key';
  static const String _remoteBasePath = '/JournalApp';

  final Dio _dio = Dio();
  String? _currentCodeVerifier;

  // --- App Key ---

  Future<void> saveAppKey(String appKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appKeyKey, appKey);
  }

  Future<String?> getAppKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appKeyKey);
  }

  Future<void> clearAppKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appKeyKey);
  }

  // --- PKCE ---

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // --- Auth ---

  Future<bool> get isAuthenticated async {
    final token = await _getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> _saveTokens(String accessToken, String? refreshToken, {int? expiresIn}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
    final seconds = expiresIn ?? 14400;
    final expiry = DateTime.now().add(Duration(seconds: seconds));
    await prefs.setString('dropbox_token_expiry', expiry.toIso8601String());
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<void> authenticate(String appKey) async {
    _currentCodeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(_currentCodeVerifier!);

    final authUrl = Uri.parse(
      'https://www.dropbox.com/oauth2/authorize'
      '?client_id=$appKey'
      '&response_type=code'
      '&token_access_type=offline'
      '&scope=files.content.write+files.content.read'
      '&code_challenge=$codeChallenge'
      '&code_challenge_method=S256',
    );

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open browser');
    }
  }

  String getAuthUrl(String appKey) {
    _currentCodeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(_currentCodeVerifier!);

    return 'https://www.dropbox.com/oauth2/authorize'
        '?client_id=$appKey'
        '&response_type=code'
        '&token_access_type=offline'
        '&scope=files.content.write+files.content.read'
        '&code_challenge=$codeChallenge'
        '&code_challenge_method=S256';
  }

  Future<void> exchangeCodeAndSave(String appKey, String code) async {
    final tokenData = await _exchangeCode(appKey, code);
    await _saveTokens(
      tokenData['access_token']!,
      tokenData['refresh_token'],
      expiresIn: tokenData['expires_in'] as int?,
    );
    await saveAppKey(appKey);
  }

  Future<Map<String, dynamic>> _exchangeCode(String appKey, String code) async {
    if (_currentCodeVerifier == null) {
      throw Exception('No code verifier — call authenticate() first');
    }

    final response = await _dio.post(
      'https://api.dropbox.com/oauth2/token',
      data: {
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': appKey,
        'code_verifier': _currentCodeVerifier,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    _currentCodeVerifier = null;
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> _refreshAccessToken(String appKey) async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token');

    final response = await _dio.post(
      'https://api.dropbox.com/oauth2/token',
      data: {
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
        'client_id': appKey,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = response.data;
    await _saveTokens(
      data['access_token'] as String,
      null,
      expiresIn: data['expires_in'] as int?,
    );
  }

  Future<void> logout() async {
    await _clearTokens();
    await clearAppKey();
  }

  // --- HTTP Helpers ---

  Future<String> _requireToken() async {
    final token = await _getAccessToken();
    if (token == null) throw Exception('Not authenticated');
    return token;
  }

  Options _authOptions(String token) => Options(
        headers: {'Authorization': 'Bearer $token'},
      );

  // --- File Operations ---

  Future<void> uploadFile(String localPath, String remotePath) async {
    final token = await _requireToken();
    final file = File(localPath);
    final data = await file.readAsBytes();

    await _dio.post(
      'https://content.dropboxapi.com/2/files/upload',
      data: data,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': jsonEncode({
            'path': '$_remoteBasePath$remotePath',
            'mode': 'overwrite',
          }),
        },
      ),
    );
  }

  Future<List<int>> downloadFile(String remotePath) async {
    final token = await _requireToken();
    final response = await _dio.post<ResponseBody>(
      'https://content.dropboxapi.com/2/files/download',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': '',
          'Dropbox-API-Arg': jsonEncode({
            'path': '$_remoteBasePath$remotePath',
          }),
        },
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data!.stream;
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<List<String>> listFiles(String remotePath) async {
    final token = await _requireToken();
    final response = await _dio.post(
      'https://api.dropboxapi.com/2/files/list_folder',
      data: {'path': '$_remoteBasePath$remotePath'},
      options: _authOptions(token),
    );

    final entries = response.data['entries'] as List;
    return entries
        .where((e) => e['.tag'] == 'file')
        .map<String>((e) => e['name'] as String)
        .toList();
  }

  Future<void> deleteFile(String remotePath) async {
    final token = await _requireToken();
    await _dio.post(
      'https://api.dropboxapi.com/2/files/delete_v2',
      data: {'path': '$_remoteBasePath$remotePath'},
      options: _authOptions(token),
    );
  }

  Future<void> createFolder(String remotePath) async {
    final token = await _requireToken();
    await _dio.post(
      'https://api.dropboxapi.com/2/files/create_folder_v2',
      data: {'path': '$_remoteBasePath$remotePath'},
      options: _authOptions(token),
    );
  }

  // --- Sync Operations ---

  Future<void> syncJsonFile(String localPath) async {
    final appKey = await getAppKey();
    if (appKey == null) return;

    if (await _isTokenExpired()) {
      await _refreshAccessToken(appKey);
    }

    await uploadFile(localPath, '/journal_data.json');
  }

  Future<void> syncMediaFile(String localPath) async {
    final appKey = await getAppKey();
    if (appKey == null) return;

    if (await _isTokenExpired()) {
      await _refreshAccessToken(appKey);
    }

    final fileName = p.basename(localPath);
    await uploadFile(localPath, '/media/$fileName');
  }

  Future<String?> downloadJsonFile(String localPath) async {
    final appKey = await getAppKey();
    if (appKey == null) return null;

    if (await _isTokenExpired()) {
      await _refreshAccessToken(appKey);
    }

    try {
      final bytes = await downloadFile('/journal_data.json');
      final file = File(localPath);
      await file.writeAsBytes(bytes);
      return localPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadMediaFiles(String localMediaDir) async {
    final appKey = await getAppKey();
    if (appKey == null) return;

    if (await _isTokenExpired()) {
      await _refreshAccessToken(appKey);
    }

    try {
      final remoteFiles = await listFiles('/media');
      final localDir = Directory(localMediaDir);
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      for (final fileName in remoteFiles) {
        final localFile = File(p.join(localMediaDir, fileName));
        if (!await localFile.exists()) {
          final bytes = await downloadFile('/media/$fileName');
          await localFile.writeAsBytes(bytes);
        }
      }
    } catch (_) {
      // Folder might not exist yet
    }
  }

  Future<bool> _isTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString('dropbox_token_expiry');
    if (expiryStr == null) return true;
    final expiry = DateTime.parse(expiryStr);
    return DateTime.now().isAfter(expiry);
  }

  Future<void> fullSync(String localDataPath, String localMediaDir) async {
    final appKey = await getAppKey();
    if (appKey == null) return;

    if (await _isTokenExpired()) {
      await _refreshAccessToken(appKey);
    }

    // Download remote data
    final remoteData = await _downloadRemoteJson();

    // Load local data
    final localFile = File(localDataPath);
    Map<String, dynamic>? localData;
    if (await localFile.exists()) {
      localData = jsonDecode(await localFile.readAsString());
    }

    // Merge
    final merged = _mergeData(localData, remoteData);

    // Save merged locally
    await localFile.writeAsString(jsonEncode(merged));

    // Upload merged
    try {
      await uploadFile(localDataPath, '/journal_data.json');
    } catch (_) {
      try {
        await createFolder('');
      } catch (_) {}
      await uploadFile(localDataPath, '/journal_data.json');
    }

    // Sync media
    await _syncMedia(localDataPath, localMediaDir);
  }

  Future<Map<String, dynamic>?> _downloadRemoteJson() async {
    try {
      final bytes = await downloadFile('/journal_data.json');
      final json = utf8.decode(bytes);
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _mergeData(
    Map<String, dynamic>? local,
    Map<String, dynamic>? remote,
  ) {
    if (local == null && remote == null) {
      return {
        'nextEntryId': 1,
        'nextTagId': 1,
        'entries': <dynamic>[],
        'tags': <dynamic>[],
      };
    }
    if (local == null) return remote!;
    if (remote == null) return local;

    final localEntries = (local['entries'] as List?) ?? [];
    final remoteEntries = (remote['entries'] as List?) ?? [];

    // Merge entries: combine, dedup by id, keep newer updatedAt
    final entryMap = <int, Map<String, dynamic>>{};
    for (final e in localEntries) {
      final id = e['id'] as int;
      entryMap[id] = e;
    }
    for (final e in remoteEntries) {
      final id = e['id'] as int;
      final existing = entryMap[id];
      if (existing == null) {
        entryMap[id] = e;
      } else {
        final localUpdated = DateTime.parse(existing['updated_at'] as String);
        final remoteUpdated = DateTime.parse(e['updated_at'] as String);
        if (remoteUpdated.isAfter(localUpdated)) {
          entryMap[id] = e;
        }
      }
    }

    // Merge tags: combine, dedup by name
    final localTags = (local['tags'] as List?) ?? [];
    final remoteTags = (remote['tags'] as List?) ?? [];
    final tagMap = <String, Map<String, dynamic>>{};
    for (final t in localTags) {
      tagMap[t['name'] as String] = t;
    }
    for (final t in remoteTags) {
      if (!tagMap.containsKey(t['name'] as String)) {
        tagMap[t['name'] as String] = t;
      }
    }

    final nextEntryId = [
      (local['nextEntryId'] as int?) ?? 1,
      (remote['nextEntryId'] as int?) ?? 1,
    ].reduce((a, b) => a > b ? a : b);

    final nextTagId = [
      (local['nextTagId'] as int?) ?? 1,
      (remote['nextTagId'] as int?) ?? 1,
    ].reduce((a, b) => a > b ? a : b);

    return {
      'nextEntryId': nextEntryId,
      'nextTagId': nextTagId,
      'entries': entryMap.values.toList(),
      'tags': tagMap.values.toList(),
    };
  }

  Future<void> _syncMedia(String localDataPath, String localMediaDir) async {
    final data = jsonDecode(await File(localDataPath).readAsString());
    final entries = (data['entries'] as List?) ?? [];

    // Collect all local media paths referenced by entries
    final mediaPaths = <String>{};
    for (final e in entries) {
      final paths = (e['media_paths'] as String?)?.split(',').where((s) => s.isNotEmpty) ?? [];
      mediaPaths.addAll(paths);
    }

    // Upload local media files that exist
    for (final path in mediaPaths) {
      final file = File(path);
      if (await file.exists()) {
        final fileName = p.basename(path);
        try {
          await uploadFile(path, '/media/$fileName');
        } catch (_) {
          // Skip failed uploads
        }
      }
    }

    // Download remote media files that don't exist locally
    try {
      final remoteFiles = await listFiles('/media');
      final localDir = Directory(localMediaDir);
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }
      for (final fileName in remoteFiles) {
        final localFile = File(p.join(localMediaDir, fileName));
        if (!await localFile.exists()) {
          final bytes = await downloadFile('/media/$fileName');
          await localFile.writeAsBytes(bytes);
        }
      }
    } catch (_) {
      // Remote media folder might not exist yet
    }
  }
}
