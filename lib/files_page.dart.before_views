import 'package:flutter/material.dart';

import 'mysynk_api.dart';
import 'server_config.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  MySynkApi? _api;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  String _currentPath = '/';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serverUrl = await ServerConfig.getServerUrl();

      _api = MySynkApi(
        baseUrl: serverUrl,
      );

      final items = await _api!.listFiles(_currentPath);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los archivos.';
      });
    }
  }

  Future<void> _openFolder(String path) async {
    setState(() {
      _currentPath = path;
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api!.listFiles(path);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'No se pudo abrir la carpeta.';
      });
    }
  }

  void _goBack() {
    if (_currentPath == '/') {
      Navigator.of(context).pop();
      return;
    }

    final parts = _currentPath
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      _openFolder('/');
      return;
    }

    parts.removeLast();

    final parentPath = parts.isEmpty
        ? '/'
        : '/${parts.join('/')}';

    _openFolder(parentPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: const Text('Mis archivos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadFiles,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadFiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text('Esta carpeta está vacía.'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        separatorBuilder: (context, index) {
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          final item = _items[index];

          final name = item['name']?.toString() ?? 'Sin nombre';
          final type = item['type']?.toString() ?? 'file';
          final path = item['path']?.toString() ?? '';

          final isDirectory = type == 'directory';

          return ListTile(
            leading: Icon(
              isDirectory
                  ? Icons.folder
                  : Icons.insert_drive_file_outlined,
            ),
            title: Text(name),
            subtitle: Text(
              isDirectory ? 'Carpeta' : 'Archivo',
            ),
            trailing: isDirectory
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: isDirectory && path.isNotEmpty
                ? () => _openFolder(path)
                : null,
          );
        },
      ),
    );
  }
}