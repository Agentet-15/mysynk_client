import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'app_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_auth.dart';
import 'mysynk_api.dart';
import 'server_config.dart';
import 'files_page.dart';
import 'sync_pair.dart';
import 'sync/local_scanner.dart';
import 'sync/sync_engine.dart';
import 'pairing_page.dart';

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
      title: AppIdentity.name,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppIdentity.brandColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppIdentity.brandColor,
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

class _SpacePage extends StatefulWidget {
  const _SpacePage();

  @override
  State<_SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends State<_SpacePage> {
  String? _serverUrl;
  bool _loading = true;

  bool get _connected => _serverUrl != null && _serverUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadServer();
  }

  Future<void> _loadServer() async {
    final serverUrl = await ServerConfig.getServerUrl();

    if (!mounted) {
      return;
    }

    setState(() {
      _serverUrl = serverUrl;
      _loading = false;
    });
  }

  Future<void> _connectServer() async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const PairingPage(),
      ),
    );

    if (connected == true) {
      await _loadServer();
    }
  }

  void _openFiles() {
    if (!_connected) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FilesPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _connected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _connected
                            ? 'Servidor conectado'
                            : 'Servidor no conectado',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _connected
                      ? _serverUrl!
                      : 'Conecta MySynk a tu servidor para acceder a tus archivos.',
                ),
                if (!_connected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _connectServer,
                      icon: const Icon(Icons.link),
                      label: const Text('Conectar servidor'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            enabled: _connected,
            leading: const Icon(Icons.folder),
            title: const Text('Mis archivos'),
            subtitle: Text(
              _connected
                  ? 'Explorar los archivos del servidor'
                  : 'Conecta un servidor para acceder a tus archivos',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openFiles,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Copias de seguridad'),
            subtitle: const Text(
              'Gestionar las copias de este dispositivo',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _SyncPage extends StatefulWidget {
  const _SyncPage();

  @override
  State<_SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<_SyncPage> {
  static const String _storageKey = 'mysynk_sync_pairs';

  final List<SyncPair> _pairs = [];
  String? _syncingPairId;

  @override
  void initState() {
    super.initState();
    _loadPairs();
    _testLocalAccess();
  }

  Future<void> _loadPairs() async {
    final preferences = await SharedPreferences.getInstance();
    final storedPairs = preferences.getStringList(_storageKey) ?? [];

    final localPairs = <SyncPair>[];

    for (final value in storedPairs) {
      final parts = value.split('|');

      if (parts.length != 5) {
        continue;
      }

      localPairs.add(
        SyncPair(
          id: parts[0],
          localPath: parts[1],
          devicePath: parts[2],
          mode: parts[3],
          enabled: parts[4] == 'true',
        ),
      );
    }

    final deviceId = preferences.getString('mysynk_device_id');
    final serverUrl = await ServerConfig.getServerUrl();

    var finalPairs = <SyncPair>[];

    if (deviceId != null &&
        deviceId.trim().isNotEmpty &&
        serverUrl != null &&
        serverUrl.trim().isNotEmpty) {
      try {
        final api = MySynkApi(baseUrl: serverUrl);
        final serverPairs = await api.listSyncPairs();

        final currentDevicePairs = serverPairs.where((pair) {
          return pair['deviceId'] == deviceId.trim();
        }).toList();

        final usedLocalPaths = <String>{};

        for (final serverPair in currentDevicePairs) {
          final serverPairId = serverPair['id'];
          final localPath = serverPair['localPath'];
          final devicePath = serverPair['devicePath'];
          final mode = serverPair['mode'];
          final serverEnabled = serverPair['enabled'] == true;

          if (serverPairId is! String ||
              serverPairId.trim().isEmpty ||
              localPath is! String ||
              localPath.trim().isEmpty ||
              devicePath is! String ||
              mode is! String) {
            continue;
          }

          final normalizedLocalPath = localPath.trim();

          // Evita que un mismo directorio aparezca dos veces
          // aunque existan registros duplicados en el servidor.
          if (!usedLocalPaths.add(normalizedLocalPath)) {
            continue;
          }

          SyncPair? localPair;

          for (final candidate in localPairs) {
            if (candidate.localPath == normalizedLocalPath) {
              localPair = candidate;
              break;
            }
          }

          final enabled = localPair?.enabled ?? serverEnabled;

          finalPairs.add(
            SyncPair(
              id: serverPairId.trim(),
              localPath: normalizedLocalPath,
              devicePath: devicePath,
              mode: mode,
              enabled: enabled,
            ),
          );

          if (localPair != null &&
              localPair.enabled != serverEnabled) {
            await api.updateSyncPair(
              pairId: serverPairId.trim(),
              changes: {
                'enabled': localPair.enabled,
              },
            );
          }
        }

        await preferences.setStringList(
          _storageKey,
          finalPairs
              .map(
                (pair) => [
                  pair.id,
                  pair.localPath,
                  pair.devicePath,
                  pair.mode,
                  pair.enabled.toString(),
                ].join('|'),
              )
              .toList(),
        );
      } catch (_) {
        // Si el servidor no está disponible, mantenemos
        // la configuración local existente.
        finalPairs = localPairs;
      }
    } else {
      finalPairs = localPairs;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pairs
        ..clear()
        ..addAll(finalPairs);
    });
  }

  Future<void> _testLocalAccess() async {
    try {
      final dir = Directory('/storage/emulated/0/DCIM/Camera');
      var count = 0;

      await for (final entity in dir.list(
        recursive: false,
        followLinks: false,
      )) {
        debugPrint(
          'MYSYNK: ENTITY type=${entity.runtimeType} path=${entity.path}',
        );
        count++;

        if (count >= 10) {
          break;
        }
      }

      debugPrint('MYSYNK: Directory.list encontró $count elementos');
    } catch (error) {
      debugPrint('MYSYNK: ERROR Directory.list - $error');
    }
  }

  Future<void> _savePairs() async {
    final preferences = await SharedPreferences.getInstance();

    final values = _pairs
        .map(
          (pair) => [
            pair.id,
            pair.localPath,
            pair.devicePath,
            pair.mode,
            pair.enabled.toString(),
          ].join('|'),
        )
        .toList();

    await preferences.setStringList(_storageKey, values);
  }

  Future<void> _addFolder() async {
    final selectedDirectory =
        await FilePicker.getDirectoryPath();

    if (selectedDirectory == null ||
        selectedDirectory.trim().isEmpty) {
      return;
    }

    final localPath = selectedDirectory.trim();

    if (_pairs.any((pair) => pair.localPath == localPath)) {
      return;
    }

    final deviceId = await DeviceAuth.getDeviceId();

    if (deviceId == null || deviceId.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este dispositivo todavía no está emparejado con MySynk.',
          ),
        ),
      );
      return;
    }

    final serverUrl = await ServerConfig.getServerUrl();

    if (serverUrl == null || serverUrl.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay un servidor MySynk configurado.',
          ),
        ),
      );
      return;
    }

    final api = MySynkApi(baseUrl: serverUrl);

    final devicePath = '/${localPath.split('/').last}';

    try {
      final pair = await api.createSyncPair(
        deviceId: deviceId.trim(),
        localPath: localPath,
        devicePath: devicePath,
        mode: 'ONE_WAY_UPLOAD',
      );

      final pairId = pair['id'];

      if (pairId is! String || pairId.trim().isEmpty) {
        throw Exception(
          'El servidor no devolvió el identificador de la sincronización.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pairs.add(
          SyncPair(
            id: pairId.trim(),
            localPath: localPath,
            devicePath: devicePath,
            mode: 'ONE_WAY_UPLOAD',
            enabled: true,
          ),
        );
      });

      await _savePairs();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carpeta sincronizada agregada.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo agregar la carpeta: $error',
          ),
        ),
      );
    }
  }

  Future<void> _removePair(int index, SyncPair pair) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar de sincronización'),
          content: Text(
            '¿Quieres quitar "${pair.localPath}" de la sincronización?\n\n'
            'La carpeta del teléfono y los archivos que ya estén respaldados '
            'en el servidor no se eliminarán.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final serverUrl = await ServerConfig.getServerUrl();

    if (serverUrl == null || serverUrl.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay un servidor MySynk configurado.',
          ),
        ),
      );
      return;
    }

    final api = MySynkApi(baseUrl: serverUrl);

    try {
      await api.deleteSyncPair(pair.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _pairs.removeAt(index);
      });

      await _savePairs();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carpeta eliminada de la sincronización.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar la sincronización: $error',
          ),
        ),
      );
    }
  }

  Future<void> _setPairEnabled(
    int index,
    SyncPair pair,
    bool value,
  ) async {
    final serverUrl = await ServerConfig.getServerUrl();

    if (serverUrl == null || serverUrl.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay un servidor MySynk configurado.',
          ),
        ),
      );
      return;
    }

    final api = MySynkApi(baseUrl: serverUrl);

    try {
      await api.updateSyncPair(
        pairId: pair.id,
        changes: {
          'enabled': value,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pairs[index] = SyncPair(
          id: pair.id,
          localPath: pair.localPath,
          devicePath: pair.devicePath,
          mode: pair.mode,
          enabled: value,
        );
      });

      await _savePairs();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar la sincronización: $error',
          ),
        ),
      );
    }
  }

  Future<void> _syncPair(SyncPair pair) async {
    if (_syncingPairId != null) {
      return;
    }

    final token = await DeviceAuth.getAccessToken();
    final serverUrl = await ServerConfig.getServerUrl();

    if (token == null ||
        serverUrl == null ||
        serverUrl.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Empareja el dispositivo de nuevo antes de sincronizar.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _syncingPairId = pair.id;
    });

    try {
      final engine = SyncEngine(
        api: MySynkApi(baseUrl: serverUrl),
        scanner: LocalScanner(),
      );

      final result = await engine.run(
        pairId: pair.id,
        localPath: pair.localPath,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync ${result.status}: ↑${result.uploaded} '
            '↓${result.downloaded} · borrados ${result.deletedRemote}/${result.deletedLocal}'
            ' · conflictos ${result.conflicts} · errores ${result.errors}',
          ),
        ),
      );
    } on MySynkApiException catch (error) {
      if (error.isDeviceRevoked || error.isTokenProblem) {
        await DeviceAuth.clear();
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo sincronizar: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncingPairId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sincronización',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: _addFolder,
                icon: const Icon(Icons.add),
                label: const Text('Agregar carpeta'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pairs.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Todavía no tienes carpetas sincronizadas.',
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _pairs.length,
                itemBuilder: (context, index) {
                  final pair = _pairs[index];

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(pair.localPath),
                      subtitle: Text(
                        '${pair.localPath} → ${pair.devicePath}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: pair.enabled,
                            onChanged: (value) =>
                                _setPairEnabled(index, pair, value),
                          ),
                          IconButton(
                            tooltip: 'Sincronizar ahora',
                            icon: _syncingPairId == pair.id
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            onPressed: _syncingPairId == null
                                ? () => _syncPair(pair)
                                : null,
                          ),
                          IconButton(
                            tooltip: 'Eliminar de sincronización',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _removePair(index, pair),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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

      if (serverUrl == null || serverUrl.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _testingConnection = false;
          _connectionStatus = 'No hay un servidor conectado.';
        });
        return;
      }

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
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PairingPage(),
              ),
            );
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Emparejar servidor'),
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
