import 'package:flutter/material.dart';
import 'app_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_auth.dart';
import 'device_info.dart';
import 'folder_picker_page.dart';
import 'mysynk_api.dart';
import 'server_config.dart';
import 'files_page.dart';
import 'sync_pair.dart';
import 'sync/local_fs.dart';
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
  final List<Map<String, dynamic>> _devices = [];
  String? _syncingPairId;
  bool _loadingDevices = true;

  @override
  void initState() {
    super.initState();
    _loadPairs();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final serverUrl = await ServerConfig.getServerUrl();

    if (serverUrl == null || serverUrl.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingDevices = false);
      return;
    }

    try {
      final devices = await MySynkApi(baseUrl: serverUrl).listDevices();

      if (!mounted) {
        return;
      }

      final order = {
        'ACTIVE': 0,
        'PENDING': 1,
        'ARCHIVED': 2,
        'REVOKED': 3,
      };

      devices.sort((a, b) {
        final aStatus = a['status'] as String? ?? '';
        final bStatus = b['status'] as String? ?? '';
        return (order[aStatus] ?? 9).compareTo(order[bStatus] ?? 9);
      });

      setState(() {
        _devices
          ..clear()
          ..addAll(devices);
        _loadingDevices = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingDevices = false);
    }
  }

  String _deviceStatus(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Activo';
      case 'PENDING':
        return 'Pendiente';
      case 'ARCHIVED':
        return 'Archivado';
      case 'REVOKED':
        return 'Revocado';
      default:
        return status;
    }
  }

  String _folderLabel(String localPath) {
    if (!localPath.toLowerCase().startsWith('content://')) {
      return localPath;
    }

    final uri = Uri.tryParse(localPath);
    var label = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : localPath;

    try {
      label = Uri.decodeComponent(label);
    } catch (_) {
      // Se conserva el segmento original.
    }

    final colon = label.lastIndexOf(':');

    if (colon >= 0 && colon < label.length - 1) {
      label = label.substring(colon + 1);
    }

    return label.isEmpty ? 'Carpeta' : label;
  }

  String _lastSeen(Map<String, dynamic> device) {
    final raw = device['lastSeenAt'];

    if (raw is! String) {
      return 'Sin contacto';
    }

    final parsed = DateTime.tryParse(raw);

    if (parsed == null) {
      return 'Sin contacto';
    }

    final minutes = DateTime.now().difference(parsed).inMinutes;

    if (minutes < 1) {
      return 'Ahora';
    }

    if (minutes < 60) {
      return 'Hace $minutes min';
    }

    final local = parsed.toLocal();
    return '${local.day}/${local.month} ${local.hour}:'
        '${local.minute.toString().padLeft(2, '0')}';
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

  /// Nombre legible del teléfono, usado como carpeta en el servidor.
  Future<String> _backupDeviceName(MySynkApi api) async {
    final stored = await DeviceAuth.getName();

    if (stored != null && stored.trim().isNotEmpty) {
      return DeviceAuth.normalizeDeviceName(stored);
    }

    try {
      final response = await api.getDeviceMe();
      final device = response['device'];

      if (device is Map && device['name'] is String) {
        final name =
            DeviceAuth.normalizeDeviceName(device['name'] as String);

        if (name.isNotEmpty) {
          await DeviceAuth.saveName(name);
          return name;
        }
      }
    } catch (_) {
      // Si el servidor no responde se usa el nombre de Android.
    }

    final label = await DeviceInfo.getLabel();
    final fallback = DeviceAuth.normalizeDeviceName(
      label ?? 'Mi teléfono',
    );

    return fallback.isEmpty ? 'Mi teléfono' : fallback;
  }

  Future<void> _addFolder() async {
    final selected = await Navigator.of(context)
        .push<List<FolderChoice>>(
      MaterialPageRoute<List<FolderChoice>>(
        builder: (_) => const FolderPickerPage(),
      ),
    );

    if (selected == null || selected.isEmpty || !mounted) {
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
    final phoneName = await _backupDeviceName(api);

    final toCreate = <FolderChoice>[];
    final usedNames = <String>{};

    for (final folder in selected) {
      final localPath = folder.uri.trim();

      if (localPath.isEmpty ||
          _pairs.any((pair) => pair.localPath == localPath)) {
        continue;
      }

      var folderName =
          DeviceAuth.normalizeDeviceName(folder.name);

      if (folderName.isEmpty) {
        folderName = 'Carpeta';
      }

      var uniqueName = folderName;
      var suffix = 2;

      while (!usedNames.add(uniqueName.toLowerCase())) {
        uniqueName = '$folderName ($suffix)';
        suffix++;
      }

      toCreate.add(
        FolderChoice(uri: localPath, name: uniqueName),
      );
    }

    if (toCreate.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Todas las carpetas elegidas ya están sincronizadas.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar carpetas'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Teléfono: $phoneName',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se crearán estas carpetas en el servidor:',
                ),
                const SizedBox(height: 8),
                for (final folder in toCreate)
                  Text('• /$phoneName/${folder.name}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sincronizar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final created = <SyncPair>[];
    final errors = <String>[];

    for (final folder in toCreate) {
      final safePhoneName =
          DeviceAuth.normalizeDeviceName(phoneName);
      final devicePath = '/$safePhoneName/${folder.name}';

      try {
        final pair = await api.createSyncPair(
          deviceId: deviceId.trim(),
          localPath: folder.uri,
          devicePath: devicePath,
          mode: 'ONE_WAY_UPLOAD',
        );

        final pairId = pair['id'];

        if (pairId is! String || pairId.trim().isEmpty) {
          throw Exception(
            'El servidor no devolvió el identificador.',
          );
        }

        created.add(
          SyncPair(
            id: pairId.trim(),
            localPath: folder.uri,
            devicePath: devicePath,
            mode: 'ONE_WAY_UPLOAD',
            enabled: true,
          ),
        );
      } catch (error) {
        errors.add('${folder.name}: $error');
      }
    }

    if (created.isNotEmpty) {
      setState(() {
        _pairs.addAll(created);
      });
      await _savePairs();
    }

    if (!mounted) {
      return;
    }

    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se agregaron ${created.length} carpeta(s) '
            'de $phoneName.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se agregaron ${created.length} carpeta(s). '
            'Fallos: ${errors.join('; ')}',
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

  /// Estructura informativa de una carpeta, para ver cuánto hay
  /// que cargar antes de decidir.
  Future<Map<String, dynamic>> _pairInfo(MySynkApi api, SyncPair pair) async {
    var localFiles = 0;
    var localDirs = 0;

    try {
      final fs = LocalFs.forPath(pair.localPath);
      final entries = await LocalScanner(fs: fs).scan(pair.localPath);
      localFiles = entries.where((e) => e.type == 'file').length;
      localDirs = entries.where((e) => e.type == 'directory').length;
    } catch (error) {
      localFiles = 0;
      localDirs = 0;
    }

    var remoteFiles = 0;

    try {
      final status = await api.getSyncStatus(pair.id);
      final count = status['fileCount'];
      if (count is int) remoteFiles = count;
    } catch (_) {
      remoteFiles = 0;
    }

    return {
      'localFiles': localFiles,
      'localDirs': localDirs,
      'remoteFiles': remoteFiles,
    };
  }

  Future<void> _showPairInfo(SyncPair pair) async {
    final serverUrl = await ServerConfig.getServerUrl();

    if (serverUrl == null || serverUrl.trim().isEmpty) {
      return;
    }

    final api = MySynkApi(baseUrl: serverUrl);
    final info = await _pairInfo(api, pair);

    if (!mounted) {
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Información de la carpeta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Carpeta: ${_folderLabel(pair.localPath)}'),
              Text('Ruta en el servidor: ${pair.devicePath}'),
              const SizedBox(height: 8),
              Text('Archivos locales: ${info['localFiles']}'),
              Text('Carpetas locales: ${info['localDirs']}'),
              Text('Archivos en el servidor: ${info['remoteFiles']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Volver a sincronizar'),
            ),
          ],
        );
      },
    ).then((result) {
      if (result == true) {
        _syncPair(pair);
      }
    });
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
      final fs = LocalFs.forPath(pair.localPath);
      final engine = SyncEngine(
        api: MySynkApi(baseUrl: serverUrl),
        fs: fs,
        scanner: LocalScanner(fs: fs),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.devices_other),
                      const SizedBox(width: 8),
                      Text(
                        'Dispositivos',
                        style:
                            Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Actualizar dispositivos',
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadDevices,
                      ),
                    ],
                  ),
                  if (_loadingDevices)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No hay dispositivos emparejados.',
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 170,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final status =
                              device['status'] as String? ?? '';
                          final name =
                              device['name'] as String? ?? 'Dispositivo';
                          final type =
                              device['type'] as String? ?? '';

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              status == 'ACTIVE'
                                  ? Icons.check_circle
                                  : Icons.devices,
                              color: status == 'ACTIVE'
                                  ? Colors.green
                                  : null,
                            ),
                            title: Text(name),
                            subtitle: Text(
                              '${_deviceStatus(status)} · '
                              '${_lastSeen(device)} · $type',
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_pairs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder_off_outlined,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Todavía no tienes carpetas sincronizadas.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca «Agregar carpeta» para elegir cuáles '
                      'se sincronizan.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
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
                      title: Text(_folderLabel(pair.localPath)),
                      subtitle: Text(
                        '${pair.devicePath} · ${pair.mode}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Información',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => _showPairInfo(pair),
                          ),
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
  final TextEditingController _nameController =
      TextEditingController();
  bool _testingConnection = false;
  bool _savingName = false;
  String _connectionStatus = 'Todavía no conectado';
  String _deviceName = 'Sin nombre';

  @override
  void initState() {
    super.initState();
    _loadDeviceName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceName() async {
    final stored = await DeviceAuth.getName();
    var name = stored?.trim() ?? '';

    if (name.isEmpty) {
      name = await DeviceInfo.getLabel() ?? 'Mi teléfono';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _deviceName = name;
      _nameController.text = name;
    });
  }

  Future<void> _saveDeviceName() async {
    final name =
        DeviceAuth.normalizeDeviceName(_nameController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe un nombre para el teléfono.'),
        ),
      );
      return;
    }

    setState(() => _savingName = true);

    final serverUrl = await ServerConfig.getServerUrl();

    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      try {
        final device = await MySynkApi(baseUrl: serverUrl)
            .updateDeviceName(name);
        final remote = device['name'];

        if (remote is String && remote.trim().isNotEmpty) {
          await DeviceAuth.saveName(remote);
        }
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() => _savingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar el nombre en el servidor: $error',
            ),
          ),
        );
        return;
      }
    } else {
      await DeviceAuth.saveName(name);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _deviceName = name;
      _savingName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nombre del teléfono guardado.'),
      ),
    );
  }

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.phone_android_outlined,
                  ),
                  title: const Text('Nombre de este teléfono'),
                  subtitle: Text(
                    'Aparece en el servidor como /$_deviceName',
                  ),
                ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del dispositivo',
                    hintText: 'Ej. Motorola de Ana',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 60,
                  onSubmitted: (_) => _saveDeviceName(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _savingName
                        ? null
                        : _saveDeviceName,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _savingName
                          ? 'Guardando...'
                          : 'Guardar nombre',
                    ),
                  ),
                ),
              ],
            ),
          ),
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
