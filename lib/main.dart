import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mysynk_api.dart';
import 'server_config.dart';
import 'files_page.dart';

void main() {
  runApp(const MySynkApp());
}

class MySynkApp extends StatefulWidget {
  const MySynkApp({super.key});

  @override
  State<MySynkApp> createState() => _MySynkAppState();
}

class _MySynkAppState extends State<MySynkApp> {
  static const _themePreferenceKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_themePreferenceKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode = switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _themePreferenceKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MySynk',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: MySynkHomePage(
        themeMode: _themeMode,
        onThemeChanged: _setThemeMode,
      ),
    );
  }
}

class MySynkHomePage extends StatefulWidget {
  const MySynkHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<MySynkHomePage> createState() => _MySynkHomePageState();
}

class _MySynkHomePageState extends State<MySynkHomePage> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Mi espacio',
    'Sincronización',
    'Configuración',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Mi espacio',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            selectedIcon: Icon(Icons.sync),
            label: 'Sincronización',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const _SpacePage();
      case 1:
        return const _SyncPage();
      case 2:
        return _SettingsPage(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        );
      default:
        return const _SpacePage();
    }
  }
}

class _SpacePage extends StatelessWidget {
  const _SpacePage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'MySynk',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu espacio privado para archivos y copias de seguridad.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Mis archivos'),
            subtitle: const Text('Explorar los archivos del servidor'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FilesPage(),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Copias de seguridad'),
            subtitle: const Text('Gestionar las copias de este dispositivo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _SyncPage extends StatelessWidget {
  const _SyncPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sync,
            size: 64,
          ),
          const SizedBox(height: 20),
          Text(
            'Sincronización',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Aquí aparecerá el estado de tus sincronizaciones.',
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _testingConnection = false;
  String _connectionStatus = 'Todavía no conectado';

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionStatus = 'Comprobando conexión...';
    });

    try {
      final serverUrl = await ServerConfig.getServerUrl();

      final api = MySynkApi(
        baseUrl: serverUrl,
      );

      final connected = await api.testConnection();

      if (!mounted) {
        return;
      }

      setState(() {
        _testingConnection = false;
        _connectionStatus = connected
            ? 'Servidor conectado'
            : 'La API respondió con un formato inesperado';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _testingConnection = false;
        _connectionStatus = 'No se pudo conectar al servidor';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Servidor'),
          subtitle: Text(_connectionStatus),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _testingConnection ? null : _testConnection,
          icon: _testingConnection
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.wifi_find),
          label: Text(
            _testingConnection
                ? 'Comprobando...'
                : 'Probar conexión',
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.brightness_6_outlined),
                  title: Text('Tema'),
                  subtitle: Text('Elige cómo quieres ver MySynk'),
                ),
                RadioGroup<ThemeMode>(
                  groupValue: widget.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      widget.onThemeChanged(value);
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: const Text('Sistema'),
                        subtitle: const Text(
                          'Usar la configuración del dispositivo',
                        ),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: const Text('Claro'),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: const Text('Oscuro'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const ListTile(
          leading: Icon(Icons.phone_android_outlined),
          title: Text('Este dispositivo'),
          subtitle: Text('Identidad del dispositivo pendiente'),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Acerca de MySynk'),
          subtitle: Text('Cliente Flutter de MySynk'),
        ),
      ],
    );
  }
}
