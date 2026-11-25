import 'package:flutter/material.dart';

import 'saf_directory_picker.dart';

/// Carpeta elegida por el usuario para sincronizar.
class FolderChoice {
  const FolderChoice({
    required this.uri,
    required this.name,
  });

  final String uri;
  final String name;
}

/// Selector de carpetas del teléfono.
///
/// Ofrece las carpetas habituales y, para cualquier otra, el explorador
/// de archivos de Android. Permite seleccionar varias a la vez.
class FolderPickerPage extends StatefulWidget {
  const FolderPickerPage({super.key});

  @override
  State<FolderPickerPage> createState() => _FolderPickerPageState();
}

class _FolderPickerPageState extends State<FolderPickerPage> {
  static const List<(String, String)> _suggestions = [
    ('Cámara', 'DCIM/Camera'),
    ('Fotos', 'DCIM'),
    ('Descargas', 'Download'),
    ('Documentos', 'Documents'),
    ('Imágenes', 'Pictures'),
    ('Música', 'Music'),
    ('WhatsApp', 'WhatsApp/Media'),
  ];

  final List<FolderChoice> _selected = [];
  bool _checking = false;

  bool _isSelected(String uri) =>
      _selected.any((folder) => folder.uri == uri);

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleSuggested(String label, String path) async {
    final uri = SafDirectoryPicker.uriForInternalFolder(path);

    if (_isSelected(uri)) {
      setState(
        () => _selected.removeWhere((folder) => folder.uri == uri),
      );
      return;
    }

    setState(() => _checking = true);

    final available = await SafDirectoryPicker.checkDirectory(uri);

    if (!mounted) {
      return;
    }

    setState(() => _checking = false);

    if (!available) {
      _showMessage(
        'Android no permite acceder a "$label". '
        'Usa «Elegir otra carpeta».',
      );
      return;
    }

    setState(
      () => _selected.add(
        FolderChoice(uri: uri, name: label),
      ),
    );
  }

  Future<void> _pickOtherFolder() async {
    try {
      final directory = await SafDirectoryPicker().pickDirectory();

      if (directory == null || !mounted) {
        return;
      }

      final uri = directory.uri.trim();

      if (uri.isEmpty || _isSelected(uri)) {
        return;
      }

      final name = directory.name.trim().isEmpty
          ? 'Carpeta'
          : directory.name.trim();

      setState(
        () => _selected.add(
          FolderChoice(uri: uri, name: name),
        ),
      );
    } catch (error) {
      _showMessage(
        'No se pudo abrir el explorador de Android: $error',
      );
    }
  }

  void _finish() {
    if (_selected.isEmpty) {
      _showMessage('Selecciona al menos una carpeta.');
      return;
    }

    Navigator.of(context).pop<List<FolderChoice>>(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir carpetas'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _finish,
            child: Text(
              _selected.isEmpty
                  ? 'Listo'
                  : 'Listo (${_selected.length})',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Marca las carpetas del teléfono que quieres '
                'sincronizar. En el servidor se guardarán dentro '
                'de una carpeta con el nombre de este teléfono.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Carpetas habituales',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._suggestions.map(
            (suggestion) => CheckboxListTile(
              title: Text(suggestion.$1),
              subtitle: Text(suggestion.$2),
              value: _isSelected(
                SafDirectoryPicker.uriForInternalFolder(
                  suggestion.$2,
                ),
              ),
              onChanged: _checking
                  ? null
                  : (_) =>
                      _toggleSuggested(suggestion.$1, suggestion.$2),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Elegir otra carpeta'),
            subtitle: const Text(
              'Abre el explorador de archivos de Android',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickOtherFolder,
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Seleccionadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final folder in _selected)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle),
                      title: Text(folder.name),
                      trailing: IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(
                          () => _selected.remove(folder),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
