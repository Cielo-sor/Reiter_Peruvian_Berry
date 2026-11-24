import 'dart:io';
import 'dart:typed_data';

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
        child: _PrivateImage(url: record.annotatedUrl),
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
                  child: _PrivateImage(url: it.annotatedUrl, size: 56),
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
class _PrivateImage extends StatefulWidget {
  final String url;
  final double? size;
  const _PrivateImage({required this.url, this.size});

  @override
  State<_PrivateImage> createState() => _PrivateImageState();
}

class _PrivateImageState extends State<_PrivateImage> {
  late Future<Uint8List> _photo = ApiService.annotatedImage(widget.url);

  @override
  void didUpdateWidget(covariant _PrivateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) _photo = ApiService.annotatedImage(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return Image.memory(snapshot.data!, width: widget.size, height: widget.size,
              cacheWidth: widget.size == null ? null : 112, fit: BoxFit.cover);
        }
        return SizedBox(
          width: widget.size,
          height: widget.size ?? 120,
          child: Center(child: Icon(snapshot.hasError ? Icons.broken_image : Icons.image_outlined)),
        );
      },
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSessionChanged;
  const SettingsScreen({super.key, required this.onSessionChanged});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _status = message);
    } catch (error) {
      if (mounted) setState(() => _status = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _save() async {
    await ApiService.setBaseUrl(_url.text);
    if (mounted) widget.onSessionChanged();
    return await ApiService.checkHealth() ? 'Conectado correctamente' : 'No se pudo conectar';
  }

  Future<String> _signIn() async {
    await ApiService.setBaseUrl(_url.text);
    if (mounted) widget.onSessionChanged();
    await ApiService.signIn(_email.text, _password.text);
    if (mounted) _password.clear();
    return 'Sesión iniciada. Ya puedes enviar fotos.';
  }

  Future<String> _signOut() async {
    try {
      await ApiService.signOut();
    } finally {
      if (mounted) widget.onSessionChanged();
    }
    return 'Sesión cerrada.';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('URL del servidor', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(
        controller: _url,
        enabled: !_busy,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'http://192.168.1.50:8000'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: _busy ? null : () => _run(_save), child: const Text('Guardar y probar')),
      const SizedBox(height: 24),
      TextField(
        controller: _email,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Correo'),
      ),
      TextField(
        controller: _password,
        enabled: !_busy,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Contraseña'),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _busy ? null : () => _run(_signIn), child: const Text('Iniciar sesión')),
      TextButton(onPressed: _busy ? null : () => _run(_signOut), child: const Text('Cerrar sesión')),
      if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!)),
      const SizedBox(height: 24),
      const Text('Emulador Android: http://10.0.2.2:8000\nCelular por USB (adb reverse): http://localhost:8000\nCelular por Wi-Fi: IP de tu PC en la misma red.'),
    ]);
  }
}
