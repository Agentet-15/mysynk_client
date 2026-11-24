import 'dart:io';

import 'package:crypto/crypto.dart';

/// Entrada del manifiesto enviado al servidor.
///
/// `path` siempre es relativo a la carpeta del par y usa `/` como
/// separador, independientemente del sistema operativo.
class LocalFileEntry {
  const LocalFileEntry({
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.hash,
    this.type = 'file',
  });

  final String path;
  final int size;
  final DateTime modifiedAt;
  final String hash;
  final String type;

  Map<String, dynamic> toManifestEntry() {
    final entry = <String, dynamic>{
      'path': path,
      'type': type,
    };

    if (type != 'directory') {
      entry
        ..['size'] = size
        ..['modified'] = modifiedAt.toUtc().toIso8601String()
        ..['hash'] = hash;
    }

    return entry;
  }
}

class LocalScanner {
  Future<List<LocalFileEntry>> scan(String rootPath) async {
    final root = Directory(rootPath);

    if (!await root.exists()) {
      throw Exception('La carpeta local no existe: $rootPath');
    }

    final files = <LocalFileEntry>[];
    final normalizedRoot = _normalize(root.path);

    await for (final entity in root.list(
      recursive: true,
      followLinks: false,
    )) {
      final relativePath = _relativePath(
        normalizedRoot,
        _normalize(entity.path),
      );

      if (relativePath.isEmpty) {
        continue;
      }

      if (entity is Directory) {
        files.add(
          LocalFileEntry(
            path: relativePath,
            size: 0,
            modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
            hash: '',
            type: 'directory',
          ),
        );
        continue;
      }

      if (entity is! File) {
        continue;
      }

      try {
        final stat = await entity.stat();

        if (stat.type != FileSystemEntityType.file) {
          continue;
        }

        final hash = await sha256.bind(entity.openRead()).first;

        files.add(
          LocalFileEntry(
            path: relativePath,
            size: stat.size,
            modifiedAt: stat.modified,
            hash: hash.toString(),
          ),
        );
      } on FileSystemException {
        // El archivo puede desaparecer mientras se escanea.
        // Continuamos con los demás archivos.
      }
    }

    files.sort((a, b) => a.path.compareTo(b.path));

    return files;
  }

  String _normalize(String value) =>
      value.replaceAll(r'\', '/').replaceFirst(RegExp(r'/$'), '');

  String _relativePath(String root, String full) {
    if (!full.startsWith(root)) {
      throw Exception(
        'El archivo $full no pertenece a la carpeta $root.',
      );
    }

    var relative = full.substring(root.length);

    while (relative.startsWith('/')) {
      relative = relative.substring(1);
    }

    return relative;
  }
}
