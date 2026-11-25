import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_fs.dart';

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

/// Escanea la carpeta local y construye el manifiesto.
///
/// Funciona tanto con rutas reales como con carpetas SAF (`content://`).
class LocalScanner {
  const LocalScanner({this.fs});

  final LocalFs? fs;

  Future<List<LocalFileEntry>> scan(String rootPath) async {
    final filesystem = fs ?? LocalFs.forPath(rootPath);
    final entries = await filesystem.list(rootPath);

    // El manifiesto se calcula en un isolate de fondo: con carpetas
    // grandes (WhatsApp de ~40 GB) generar hashes de cada archivo en el
    // hilo de UI congelaría la app (ANR).
    final args = _ScanArgs(
      rootPath: rootPath,
      filesystem: filesystem,
      entries: entries,
    );

    try {
      return await compute(_buildManifest, args);
    } on Object {
      // Si ya estamos en un isolate de fondo se ejecuta directamente.
      return _buildManifest(args);
    }
  }
}

class _ScanArgs {
  const _ScanArgs({
    required this.rootPath,
    required this.filesystem,
    required this.entries,
  });

  final String rootPath;
  final LocalFs filesystem;
  final List<LocalFsEntry> entries;
}

Future<List<LocalFileEntry>> _buildManifest(_ScanArgs args) async {
  final manifest = <LocalFileEntry>[];

  for (final entry in args.entries) {
    final hash = entry.type == 'directory'
        ? ''
        : await args.filesystem.hash(args.rootPath, entry.path);

    manifest.add(
      LocalFileEntry(
        path: entry.path,
        size: entry.size,
        modifiedAt: entry.modified,
        hash: hash,
        type: entry.type,
      ),
    );
  }

  manifest.sort((a, b) => a.path.compareTo(b.path));
  return manifest;
}
