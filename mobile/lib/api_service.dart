import 'dart:convert';
import 'dart:io';

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
  // 10.0.2.2 = localhost de la PC visto desde el emulador Android.
  // Con celular por USB + adb reverse usa http://localhost:8000
  // En Wi-Fi usa la IP de tu PC, ej: http://192.168.1.50:8000
  static const defaultUrl = 'http://10.0.2.2:8000';

  static Future<String> getBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_key) ?? defaultUrl).replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> setBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, url.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  static Future<bool> checkHealth() async {
    try {
      final base = await getBaseUrl();
      final r = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<DetectionRecord> detect(File image, {String lote = ''}) async {
    final base = await getBaseUrl();
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/detect'));
    req.fields['lote'] = lote;
    req.files.add(await http.MultipartFile.fromPath('file', image.path));
    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      String msg = 'Error ${res.statusCode}';
      try {
        msg = (jsonDecode(utf8.decode(res.bodyBytes))['detail'] ?? msg).toString();
      } catch (_) {}
      throw Exception(msg);
    }
    return DetectionRecord.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>, base);
  }

  static Future<List<DetectionRecord>> history() async {
    final base = await getBaseUrl();
    final r = await http
        .get(Uri.parse('$base/api/detections?limit=100'))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('Error ${r.statusCode}');
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return list
        .map((e) => DetectionRecord.fromJson(e as Map<String, dynamic>, base))
        .toList();
  }
}
