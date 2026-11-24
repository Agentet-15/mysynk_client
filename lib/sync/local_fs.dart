import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../saf_directory_picker.dart';

/// Entrada devuelta por un sistema de archivos local.
class LocalFsEntry {
  const LocalFsEntry({
    required this.path,
    required this.type,
    required this.size,
    required this.modified,
  });

  final String path;
  final String type;
  final int size;
  final DateTime modified;
}

/// Abstracción del sistema de archivos del dispositivo.
///
/// Permite que el mismo escáner y motor funcionen con carpetas reales
/// (`dart:io`) y con carpetas SAF de Android (`content://`).
abstract class LocalFs {
  const LocalFs();

  factory LocalFs.forPath(String path) {
    if (path.trim().toLowerCase().startsWith('content://')) {
      return const SafLocalFs();
    }
    return const IoLocalFs();
  }

  Future<List<LocalFsEntry>> list(String root);
  Future<Uint8List> read(String root, String relativePath);
  Future<String> hash(String root, String relativePath);
  Future<void> write(
    String root,
    String relativePath,
    Uint8List bytes,
  );
  Future<void> createDirectory(String root, String relativePath);
  Future<void> delete(
    String root,
    String relativePath, {
    required bool isDirectory,
  });
}

/// Sistema de archivos accesible por `dart:io`.
class IoLocalFs extends LocalFs {
  const IoLocalFs();

  @override
  Future<List<LocalFsEntry>> list(String root) async {
    final directory = Directory(root);

    if (!await directory.exists()) {
      throw Exception('La carpeta local no existe: $root');
    }

    final rootPath = _normalize(directory.path);
    final entries = <LocalFsEntry>[];

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = _relative(rootPath, _normalize(entity.path));

      if (relative.isEmpty) {
        continue;
      }

      if (entity is Directory) {
        entries.add(
          LocalFsEntry(
            path: relative,
            type: 'directory',
            size: 0,
            modified: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
        continue;
      }

      if (entity is! File) {
        continue;
      }

      try {
        final stat = await entity.stat();

        if (stat.type == FileSystemEntityType.file) {
          entries.add(
            LocalFsEntry(
              path: relative,
              type: 'file',
              size: stat.size,
              modified: stat.modified,
            ),
          );
        }
      } on FileSystemException {
        // El archivo pudo desaparecer mientras se escaneaba.
      }
    }

    entries.sort((a, b) => a.path.compareTo(b.path));
    return entries;
  }

  @override
  Future<Uint8List> read(String root, String relativePath) =>
      File(_join(root, relativePath)).readAsBytes();

  @override
  Future<String> hash(String root, String relativePath) async {
    final digest = await sha256
        .bind(File(_join(root, relativePath)).openRead())
        .first;
    return digest.toString();
  }

  @override
  Future<void> write(
    String root,
    String relativePath,
    Uint8List bytes,
  ) async {
    final file = File(_join(root, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> createDirectory(
    String root,
    String relativePath,
  ) async {
    await Directory(_join(root, relativePath)).create(recursive: true);
  }

  @override
  Future<void> delete(
    String root,
    String relativePath, {
    required bool isDirectory,
  }) async {
    final path = _join(root, relativePath);
    final entity = isDirectory ? Directory(path) : File(path);

    if (await entity.exists()) {
      await entity.delete(recursive: true);
    }
  }

  String _normalize(String value) =>
      value.replaceAll(r'\', '/').replaceFirst(RegExp(r'/$'), '');

  String _relative(String root, String full) {
    if (!full.startsWith(root)) {
      throw Exception('El archivo $full no pertenece a $root.');
    }

    var relative = full.substring(root.length);

    while (relative.startsWith('/')) {
      relative = relative.substring(1);
    }

    return relative;
  }

  String _join(String root, String relativePath) {
    final normalizedRoot = _normalize(root);
    final normalizedRelative = relativePath
        .replaceAll(r'\', '/')
        .replaceAll(RegExp(r'^/+'), '');
    return '$normalizedRoot${Platform.pathSeparator}'
        '${normalizedRelative.replaceAll('/', Platform.pathSeparator)}';
  }
}

/// Sistema de archivos SAF de Android (`content://`).
class SafLocalFs extends LocalFs {
  const SafLocalFs();

  @override
  Future<List<LocalFsEntry>> list(String root) async {
    final raw = await SafDirectoryPicker.channel.invokeListMethod<dynamic>(
      'listDirectory',
      {'root': root},
    );

    final entries = <LocalFsEntry>[];

    for (final item in raw ?? const <dynamic>[]) {
      if (item is! Map) {
        continue;
      }

      final path = item['path'];
      final type = item['type'];

      if (path is! String || type is! String) {
        continue;
      }

      entries.add(
        LocalFsEntry(
          path: path,
          type: type,
          size: (item['size'] as num?)?.toInt() ?? 0,
          modified: DateTime.fromMillisecondsSinceEpoch(
            (item['modified'] as num?)?.toInt() ?? 0,
          ),
        ),
      );
    }

    entries.sort((a, b) => a.path.compareTo(b.path));
    return entries;
  }

  @override
  Future<Uint8List> read(String root, String relativePath) async {
    final result = await SafDirectoryPicker.channel.invokeMethod<dynamic>(
      'readFile',
      {'root': root, 'path': relativePath},
    );

    if (result is Uint8List) {
      return result;
    }

    if (result is List<int>) {
      return Uint8List.fromList(result);
    }

    throw Exception('Android no devolvió el contenido del archivo.');
  }

  @override
  Future<String> hash(String root, String relativePath) async {
    final result = await SafDirectoryPicker.channel.invokeMethod<String>(
      'hashFile',
      {'root': root, 'path': relativePath},
    );

    if (result == null || result.isEmpty) {
      throw Exception('Android no devolvió el hash del archivo.');
    }

    return result;
  }

  @override
  Future<void> write(
    String root,
    String relativePath,
    Uint8List bytes,
  ) async {
    await SafDirectoryPicker.channel.invokeMethod<void>(
      'writeFile',
      {'root': root, 'path': relativePath, 'bytes': bytes},
    );
  }

  @override
  Future<void> createDirectory(
    String root,
    String relativePath,
  ) async {
    await SafDirectoryPicker.channel.invokeMethod<void>(
      'createDirectory',
      {'root': root, 'path': relativePath},
    );
  }

  @override
  Future<void> delete(
    String root,
    String relativePath, {
    required bool isDirectory,
  }) async {
    await SafDirectoryPicker.channel.invokeMethod<void>(
      'deleteEntry',
      {'root': root, 'path': relativePath},
    );
  }
}
