import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';

Color catColor(String c) => c == 'condicion'
    ? Colors.red.shade700
    : c == 'sano'
        ? Colors.green.shade700
        : Colors.orange.shade800;

String fmtDate(DateTime d) {
  String t(int n) => n.toString().padLeft(2, '0');
  return '${t(d.day)}/${t(d.month)}/${d.year} ${t(d.hour)}:${t(d.minute)}';
}

// ───────────────────────── Detectar ─────────────────────────
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _lote = TextEditingController();
  File? _photo;
  DetectionRecord? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _lote.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
          source: source, imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
      if (x == null) return;
      setState(() {
        _photo = File(x.path);
        _result = null;
        _error = null;
        _loading = true;
      });
      final r = await ApiService.detect(_photo!, lote: _lote.text.trim());
      if (!mounted) return;
      setState(() => _result = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _lote,
          decoration: const InputDecoration(
            labelText: 'Lote / Fundo (opcional)',
            prefixIcon: Icon(Icons.agriculture),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Tomar foto'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Galería'),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (_loading) ...[
          if (_photo != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_photo!)),
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          const Center(child: Text('Analizando imagen...')),
        ] else if (_error != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('No se pudo analizar: $_error\n\nRevisa la URL del servidor en Ajustes.',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
          )
        else if (_result != null)
          _ResultView(record: _result!)
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'Fotografía la fruta cosechada (sobre fondo liso)\npara detectar defectos de calidad y condición.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final DetectionRecord record;
  const _ResultView({required this.record});

  @override
  Widget build(BuildContext context) {
    final has = record.defectCount > 0;
    final color = !has
        ? Colors.green.shade700
        : (record.conditionCount > 0 ? Colors.red.shade700 : Colors.orange.shade800);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(record.annotatedUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image)))),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Icon(has ? Icons.warning_amber_rounded : Icons.check_circle, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(has ? 'Defectos detectados (${record.defectCount})' : 'Sin defectos detectados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final g in record.groups)
          Chip(
            avatar: CircleAvatar(radius: 6, backgroundColor: catColor(g.category)),
            label: Text('${g.display} × ${g.count}'),
          ),
      ]),
      const SizedBox(height: 4),
      const Text('Guardado y visible en el dashboard.', style: TextStyle(fontSize: 12)),
    ]);
  }
}

// ───────────────────────── Historial ─────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<DetectionRecord>> _future = ApiService.history();

  Future<void> _refresh() async {
    setState(() => _future = ApiService.history());
    await _future.catchError((_) => <DetectionRecord>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DetectionRecord>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 8),
                const Text('No se pudo conectar al servidor.\nRevisa Ajustes.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Reintentar')),
              ]),
            ),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) return const Center(child: Text('Aún no hay registros.'));
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final has = it.defectCount > 0;
              final tileColor = !has
                  ? Colors.green.shade700
                  : (it.conditionCount > 0 ? Colors.red.shade700 : Colors.orange.shade800);
              final detail = it.groups.map((g) => '${g.display}×${g.count}').join(', ');
              final lote = it.lote.isEmpty ? '' : ' · ${it.lote}';
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(it.annotatedUrl, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56, child: Icon(Icons.broken_image))),
                ),
                title: Text(has ? 'Defectos (${it.defectCount})' : 'Sin defectos',
                    style: TextStyle(color: tileColor, fontWeight: FontWeight.w600)),
                subtitle: Text('${fmtDate(it.createdAt)}$lote\n$detail'),
                isThreeLine: it.groups.isNotEmpty,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: SingleChildScrollView(
                      child: Padding(padding: const EdgeInsets.all(12), child: _ResultView(record: it)),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ───────────────────────── Ajustes ─────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  String? _status;

  @override
  void initState() {
    super.initState();
    ApiService.getBaseUrl().then((v) {
      if (mounted) _url.text = v;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ApiService.setBaseUrl(_url.text);
    setState(() => _status = 'Probando conexión...');
    final ok = await ApiService.checkHealth();
    if (!mounted) return;
    setState(() => _status = ok ? '✅ Conectado correctamente' : '❌ No se pudo conectar');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('URL del servidor', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(
        controller: _url,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'http://192.168.1.50:8000'),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _save, child: const Text('Guardar y probar')),
      if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!)),
      const SizedBox(height: 24),
      const Text('Emulador Android: http://10.0.2.2:8000\nCelular por USB (adb reverse): http://localhost:8000\nCelular por Wi-Fi: IP de tu PC en la misma red.'),
    ]);
  }
}
