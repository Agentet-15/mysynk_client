import 'dart:io';

import 'package:crypto/crypto.dart';

import '../mysynk_api.dart';
import 'local_scanner.dart';

class SyncEngineResult {
  const SyncEngineResult({
    required this.runId,
    required this.status,
    required this.uploaded,
    required this.downloaded,
    required this.deletedRemote,
    required this.deletedLocal,
    required this.conflicts,
    required this.errors,
  });

  final String? runId;
  final String status;
  final int uploaded;
  final int downloaded;
  final int deletedRemote;
  final int deletedLocal;
  final int conflicts;
  final int errors;
}

/// Ejecuta un ciclo completo de sincronización cliente-dirigida.
///
/// El servidor solo calcula el plan; el cliente escanea su carpeta,
/// envía el manifiesto y ejecuta las acciones devueltas.
class SyncEngine {
  const SyncEngine({
    required this.api,
    required this.scanner,
  });

  final MySynkApi api;
  final LocalScanner scanner;

  Future<SyncEngineResult> run({
    required String pairId,
    required String localPath,
    String operation = 'SYNC',
  }) async {
    final entries = await scanner.scan(localPath);

    final plan = await api.createSyncPlan(
      pairId,
      operation: operation,
      manifest: entries
          .map((entry) => entry.toManifestEntry())
          .toList(),
    );

    final run = plan['run'];

    if (run is! Map) {
      throw const MySynkApiException(
        statusCode: 200,
        code: 'INVALID_RESPONSE',
        message: 'El servidor no devolvió el run del plan.',
      );
    }

    final runId = run['id'] as String?;
    final actions = plan['actions'];

    var uploaded = 0;
    var downloaded = 0;
    var deletedRemote = 0;
    var deletedLocal = 0;
    var conflicts = 0;
    var errors = 0;

    if (actions is List) {
      for (final rawAction in actions) {
        if (rawAction is! Map) {
          continue;
        }

        final action = Map<String, dynamic>.from(rawAction);
        final relativePath = action['path'];

        if (relativePath is! String || relativePath.isEmpty) {
          continue;
        }

        final actionName = action['action'];

        try {
          switch (actionName) {
            case 'UPLOAD':
              await _upload(
                pairId: pairId,
                localPath: localPath,
                relativePath: relativePath,
                type: action['type'],
                entries: entries,
              );
              uploaded++;
              break;

            case 'DOWNLOAD':
              await _download(
                pairId: pairId,
                localPath: localPath,
                relativePath: relativePath,
                type: action['type'],
                runId: runId,
              );
              downloaded++;
              break;

            case 'DELETE_REMOTE':
              await api.deleteSyncFile(pairId, relativePath);
              deletedRemote++;
              break;

            case 'DELETE_LOCAL':
              await _deleteLocal(
                localPath,
                relativePath,
                isDirectory: action['type'] == 'directory',
              );

              if (runId != null) {
                await api.ackSyncAction(
                  pairId,
                  runId: runId,
                  path: relativePath,
                  status: 'done',
                );
              }

              deletedLocal++;
              break;

            case 'CONFLICT':
              conflicts++;
              break;
          }
        } on MySynkApiException catch (error) {
          errors++;

          if (runId != null && error.isDeviceRevoked) {
            rethrow;
          }

          if (runId != null) {
            try {
              await api.ackSyncAction(
                pairId,
                runId: runId,
                path: relativePath,
                status: 'error',
                error: error.message,
              );
            } catch (_) {
              // No ocultar el error original.
            }
          }
        } catch (_) {
          errors++;

          if (runId != null) {
            try {
              await api.ackSyncAction(
                pairId,
                runId: runId,
                path: relativePath,
                status: 'error',
                error: 'Error al ejecutar la acción en el dispositivo.',
              );
            } catch (_) {
              // No ocultar el error original.
            }
          }
        }
      }
    }

    String finalStatus = 'completed';

    if (runId != null) {
      try {
        final completed =
            await api.completeSyncRun(pairId, runId);
        final completedRun = completed['run'];

        if (completedRun is Map &&
            completedRun['status'] is String) {
          finalStatus = completedRun['status'] as String;
        }
      } catch (_) {
        finalStatus = errors > 0 ? 'failed' : 'unknown';
      }
    }

    return SyncEngineResult(
      runId: runId,
      status: finalStatus,
      uploaded: uploaded,
      downloaded: downloaded,
      deletedRemote: deletedRemote,
      deletedLocal: deletedLocal,
      conflicts: conflicts,
      errors: errors,
    );
  }

  Future<void> _upload({
    required String pairId,
    required String localPath,
    required String relativePath,
    required Object? type,
    required List<LocalFileEntry> entries,
  }) async {
    if (type == 'directory') {
      await api.createSyncFolder(pairId, relativePath);
      return;
    }

    LocalFileEntry? entry;

    for (final item in entries) {
      if (item.path == relativePath) {
        entry = item;
        break;
      }
    }

    if (entry == null) {
      throw Exception('No se encontró el archivo local $relativePath');
    }

    final bytes = await _localFile(localPath, relativePath).readAsBytes();

    await api.uploadSyncFile(
      pairId,
      relativePath,
      bytes,
      sha256: entry.hash,
    );
  }

  Future<void> _download({
    required String pairId,
    required String localPath,
    required String relativePath,
    required Object? type,
    required String? runId,
  }) async {
    if (type == 'directory') {
      final directory = Directory(
        _localFile(localPath, relativePath).path,
      );
      await directory.create(recursive: true);

      if (runId != null) {
        await api.ackSyncAction(
          pairId,
          runId: runId,
          path: relativePath,
          status: 'done',
        );
      }

      return;
    }

    final bytes = await api.downloadSyncFile(
      pairId,
      relativePath,
    );

    final file = _localFile(localPath, relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    if (runId != null) {
      await api.ackSyncAction(
        pairId,
        runId: runId,
        path: relativePath,
        status: 'done',
        hash: sha256.convert(bytes).toString(),
      );
    }
  }

  Future<void> _deleteLocal(
    String localPath,
    String relativePath, {
    bool isDirectory = false,
  }) async {
    final path = _localFile(localPath, relativePath).path;
    final entity = isDirectory ? Directory(path) : File(path);

    if (await entity.exists()) {
      await entity.delete(recursive: true);
    }
  }

  File _localFile(String localPath, String relativePath) {
    final normalizedRoot = localPath
        .replaceAll(r'\', '/')
        .replaceFirst(RegExp(r'/$'), '');
    final normalizedRelative = relativePath.replaceAll(
      '/',
      Platform.pathSeparator,
    );

    return File('$normalizedRoot${Platform.pathSeparator}$normalizedRelative');
  }
}
