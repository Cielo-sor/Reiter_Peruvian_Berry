import 'package:flutter/material.dart';

import 'screens.dart';

void main() => runApp(const BlueberryApp());

class BlueberryApp extends StatelessWidget {
  const BlueberryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calidad de Arándanos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4B3F8F), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF4B3F8F), brightness: Brightness.dark, useMaterial3: true),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _sessionRevision = 0;
  static const _titles = ['Detectar defectos', 'Historial', 'Ajustes'];

  @override
  Widget build(BuildContext context) {
    // Se recrea la pantalla de historial al entrar para refrescar datos.
    final pages = <Widget>[
      CaptureScreen(key: ValueKey(_sessionRevision)),
      _index == 1 ? const HistoryScreen() : const SizedBox.shrink(),
      SettingsScreen(onSessionChanged: () => setState(() => _sessionRevision++)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('🫐 ${_titles[_index]}')),
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_camera), label: 'Detectar'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
