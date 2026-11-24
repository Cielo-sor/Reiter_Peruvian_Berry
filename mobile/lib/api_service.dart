import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Detection {
  final String label;
  final String display;
  final String category; // condicion | calidad | sano
  final double confidence;
  Detection(this.label, this.display, this.category, this.confidence);

  factory Detection.fromJson(Map<String, dynamic> j) => Detection(
        j['label'] as String,
        (j['display'] ?? j['label']) as String,
        (j['category'] ?? 'calidad') as String,
        (j['confidence'] as num).toDouble(),
      );
}

class DefectGroup {
  final String display;
  final String category;
  int count;
  DefectGroup(this.display, this.category, this.count);
}

class DetectionRecord {
  final int id;
  final DateTime createdAt;
  final String lote;
  final int defectCount;
  final int conditionCount;
  final int qualityCount;
  final String annotatedUrl;
  final List<Detection> detections;

  DetectionRecord({
    required this.id,
    required this.createdAt,
    required this.lote,
    required this.defectCount,
    required this.conditionCount,
    required this.qualityCount,
    required this.annotatedUrl,
    required this.detections,
  });

  factory DetectionRecord.fromJson(Map<String, dynamic> j, String base) =>
      DetectionRecord(
        id: j['id'] as int,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        lote: (j['lote'] ?? '') as String,
        defectCount: j['defect_count'] as int,
        conditionCount: j['condition_count'] as int,
        qualityCount: j['quality_count'] as int,
        annotatedUrl: '$base${j['annotated_url']}',
        detections: (j['detections'] as List)
            .map((e) => Detection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<DefectGroup> get groups {
    final m = <String, DefectGroup>{};
    for (final d in detections) {
      final g = m.putIfAbsent(d.label, () => DefectGroup(d.display, d.category, 0));
      g.count++;
    }
    return m.values.toList();
  }
}

class ApiService {
  static const _key = 'server_url';
  static const _deviceKey = 'inspection_device_id';
  static const _secure = FlutterSecureStorage();
  static const defaultUrl = 'http://10.0.2.2:8000';
  static String? _access;
  static String? _sessionBase;
  static Future<String>? _refreshing;
  static bool _closingSession = false;

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? defaultUrl;
  }

  static Uri _baseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Escribe la URL base del servidor.');
    }
    final octets = InternetAddress.tryParse(uri.host)?.rawAddress;
    final local = uri.host == 'localhost' || uri.host == '::1' ||
        (octets != null && octets.length == 4 &&
            (octets[0] == 10 || octets[0] == 127 ||
                (octets[0] == 192 && octets[1] == 168) ||
                (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31)));
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      throw const FormatException('Usa HTTPS para un servidor en internet.');
    }
    return uri;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _baseUri(url).origin);
  }

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deviceKey);
    if (stored != null) return stored;
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await prefs.setString(_deviceKey, id);
    return id;
  }

  static Future<http.Response> _send(http.BaseRequest request,
      {Duration timeout = const Duration(seconds: 20)}) async {
    request.followRedirects = false;
    final client = http.Client();
    try {
      return await (() async {
        final response = await client.send(request);
        return http.Response.fromStream(response);
      })().timeout(timeout);
    } finally {
      client.close();
    }
  }

  static dynamic _json(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));

  static void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String? message;
    try {
      message = (_json(response) as Map<String, dynamic>)['message'] as String?;
    } on FormatException {
      // A proxy can return an HTML error page.
    } on TypeError {
      // The response may have a different JSON shape.
    }
    throw Exception(message ?? 'Error ${response.statusCode}');
  }

  static Future<http.Response> _postJson(String base, String path, Map<String, Object> data) {
    final request = http.Request('POST', _baseUri(base).resolve(path))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(data);
    return _send(request);
  }

  static String _refreshKey(String base) => 'inspection_refresh:$base';

  static Future<String> _saveSession(String base, http.Response response) async {
    _check(response);
    final data = _json(response) as Map<String, dynamic>;
    final access = data['accessToken'] as String;
    await _secure.write(key: _refreshKey(base), value: data['refreshToken'] as String);
    _sessionBase = base;
    _access = access;
    return access;
  }

  static Future<void> signIn(String email, String password) async {
    final base = _baseUri(await getBaseUrl()).origin;
    await _waitForRefresh();
    final response = await _postJson(base, '/api/v1/auth/login', {
      'email': email.trim(),
      'password': password,
      'device': {
        'deviceId': await _deviceId(),
        'platform': Platform.isIOS ? 'ios' : 'android',
        'model': '',
        'osVersion': '',
        'appVersion': '',
      },
    });
    await _saveSession(base, response);
  }

  static Future<void> _waitForRefresh() async {
    try {
      await _refreshing;
    } on Exception {
      // Explicit sign-in or sign-out can proceed after a failed refresh.
    }
  }

  static Future<void> signOut() async {
    _closingSession = true;
    try {
      await _waitForRefresh();
      final base = _baseUri(await getBaseUrl()).origin;
      final token = await _secure.read(key: _refreshKey(base));
      await _secure.delete(key: _refreshKey(base));
      _access = null;
      _sessionBase = null;
      if (token != null) {
        final response = await _postJson(base, '/api/v1/auth/logout', {'refreshToken': token});
        _check(response);
      }
    } finally {
      _closingSession = false;
    }
  }

  static Future<String> _renew(String base) async {
    final token = await _secure.read(key: _refreshKey(base));
    if (token == null) throw Exception('Inicia sesión en Ajustes.');
    final response = await _postJson(base, '/api/v1/auth/refresh', {
      'refreshToken': token,
      'deviceId': await _deviceId(),
    });
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _secure.delete(key: _refreshKey(base));
      _access = null;
      _sessionBase = null;
      throw Exception('Tu sesión terminó. Vuelve a iniciar sesión en Ajustes.');
    }
    return _saveSession(base, response);
  }

  static Future<String> _refresh(String base) async {
    if (_closingSession) throw Exception('La sesión se está cerrando.');
    if (_refreshing != null) {
      await _refreshing;
      if (_sessionBase == base && _access != null) return _access!;
    }
    final pending = _renew(base);
    _refreshing = pending;
    try {
      return await pending;
    } finally {
      _refreshing = null;
    }
  }

  static Future<http.Response> _authorized(String base,
      Future<http.BaseRequest> Function() requestFactory,
      {Duration timeout = const Duration(seconds: 20)}) async {
    final deviceId = await _deviceId();
    Future<http.Response> send(String token) async {
      final request = await requestFactory();
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['X-Device-Id'] = deviceId;
      return _send(request, timeout: timeout);
    }

    final token = _sessionBase == base && _access != null ? _access! : await _refresh(base);
    var response = await send(token);
    if (response.statusCode == 401) {
      final updated = _sessionBase == base && _access != null && _access != token
          ? _access!
          : await _refresh(base);
      response = await send(updated);
    }
    _check(response);
    return response;
  }

  static Future<bool> checkHealth() async {
    try {
      final uri = _baseUri(await getBaseUrl()).resolve('/api/v1/health');
      final response = await _send(http.Request('GET', uri), timeout: const Duration(seconds: 8));
      return response.statusCode == 200 && _json(response)['status'] == 'UP';
    } catch (_) {
      return false;
    }
  }

  static Future<DetectionRecord> detect(File image, {String lote = ''}) async {
    final base = _baseUri(await getBaseUrl()).origin;
    final uri = Uri.parse('$base/api/v1/inspecciones');
    final response = await _authorized(base, () async {
      return http.MultipartRequest('POST', uri)
        ..fields['lote'] = lote
        ..files.add(await http.MultipartFile.fromPath('file', image.path));
    }, timeout: const Duration(seconds: 90));
    return DetectionRecord.fromJson(_json(response) as Map<String, dynamic>, base);
  }

  static Future<List<DetectionRecord>> history() async {
    final base = _baseUri(await getBaseUrl()).origin;
    final response = await _authorized(base,
        () async => http.Request('GET', Uri.parse('$base/api/v1/inspecciones')));
    return (_json(response) as List)
        .map((data) => DetectionRecord.fromJson(data as Map<String, dynamic>, base))
        .toList();
  }

  static Future<Uint8List> annotatedImage(String url) async {
    final base = _baseUri(await getBaseUrl()).origin;
    final uri = Uri.parse(url);
    if (uri.origin != base) throw const FormatException('La imagen pertenece a otro servidor.');
    final response = await _authorized(base, () async => http.Request('GET', uri));
    return response.bodyBytes;
  }
}
