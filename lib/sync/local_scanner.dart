import 'dart:io';

class LocalFileEntry {
  const LocalFileEntry({
    required this.path,
    required this.size,
    required this.modifiedAt,
  });

  final String path;
  final int size;
  final DateTime modifiedAt;
}

class LocalScanner {
  Future<List<LocalFileEntry>> scan(String rootPath) async {
    final root = Directory(rootPath);

    if (!await root.exists()) {
      throw Exception('La carpeta local no existe: $rootPath');
    }

    final files = <LocalFileEntry>[];

    await for (final entity in root.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      try {
        final stat = await entity.stat();

        files.add(
          LocalFileEntry(
            path: entity.path,
            size: stat.size,
            modifiedAt: stat.modified,
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
}
