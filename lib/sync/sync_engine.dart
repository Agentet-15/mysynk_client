import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../mysynk_api.dart';
import 'local_fs.dart';
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
  SyncEngine({
    required this.api,
    LocalFs? fs,
    LocalScanner? scanner,
  })  : _fs = fs,
        scanner = scanner ?? LocalScanner(fs: fs);

  final MySynkApi api;
  final LocalFs? _fs;
  final LocalScanner scanner;

  Future<SyncEngineResult> run({
    required String pairId,
    required String localPath,
    String operation = 'SYNC',
  }) async {
    final fs = _fs ?? LocalFs.forPath(localPath);
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
              if (action['type'] == 'directory') {
                await api.createSyncFolder(pairId, relativePath);
              } else {
                await api.uploadSyncFile(
                  pairId,
                  relativePath,
                  await fs.read(localPath, relativePath),
                  sha256: _hashFor(entries, relativePath),
                );
              }
              uploaded++;
              break;

            case 'DOWNLOAD':
              await _download(
                pairId: pairId,
                fs: fs,
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
              await fs.delete(
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

  String? _hashFor(List<LocalFileEntry> entries, String path) {
    for (final entry in entries) {
      if (entry.path == path) {
        return entry.hash;
      }
    }
    return null;
  }

  Future<void> _download({
    required String pairId,
    required LocalFs fs,
    required String localPath,
    required String relativePath,
    required Object? type,
    required String? runId,
  }) async {
    if (type == 'directory') {
      await fs.createDirectory(localPath, relativePath);

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

    await fs.write(
      localPath,
      relativePath,
      Uint8List.fromList(bytes),
    );

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
}
