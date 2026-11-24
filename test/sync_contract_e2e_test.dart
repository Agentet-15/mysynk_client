// Validación end-to-end del contrato de sincronización.
//
// Ejecuta el mismo código que la app (MySynkApi, LocalScanner y
// SyncEngine) contra un servidor MySynk en marcha:
//
//   flutter test --dart-define=MYSYNK_E2E=true \
//     --dart-define=MYSYNK_URL=http://127.0.0.1:3001 \
//     test/sync_contract_e2e_test.dart
//
// Sin las variables no hace nada, para que `flutter test` siga siendo
// seguro en CI. El servidor de prueba debe usar config/storage aislados.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mysynk_client/mysynk_api.dart';
import 'package:mysynk_client/sync/local_scanner.dart';
import 'package:mysynk_client/sync/sync_engine.dart';

void main() {
  const enabled = bool.fromEnvironment('MYSYNK_E2E');
  const configuredUrl = String.fromEnvironment(
    'MYSYNK_URL',
    defaultValue: 'http://127.0.0.1:3001',
  );

  test('contrato Flutter ↔ MySynk', () async {
    if (!enabled) {
      return;
    }

    final baseUrl = configuredUrl.replaceFirst(RegExp(r'/$'), '');
    final client = http.Client();
    final suffix = DateTime.now().millisecondsSinceEpoch;

    String? pairId1;
    String? pairId2;
    late final MySynkApi anonymousApi;

    void check(bool condition, String message) {
      expect(condition, isTrue, reason: message);
    }

    Future<Map<String, dynamic>> createPairing() async {
      final response =
          await client.post(Uri.parse('$baseUrl/api/v1/pairing'));

      check(response.statusCode == 201,
          'crear sesión de emparejamiento (${response.statusCode})');

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final pairing = data['pairing'] as Map<String, dynamic>;

      check((pairing['token'] as String?)?.isNotEmpty == true,
          'el QR devuelve un token de emparejamiento');

      return pairing;
    }

    try {
      final pairing = await createPairing();

      anonymousApi = MySynkApi(baseUrl: baseUrl);
      final authorized = await anonymousApi.authorizePairing(
        token: pairing['token'] as String,
        name: 'Flutter E2E $suffix',
        type: 'android',
        platformIdentifier: 'e2e-flutter-$suffix',
      );

      final device =
          authorized['device'] as Map<String, dynamic>;
      final deviceId = device['id'] as String;
      final accessToken = authorized['accessToken'] as String?;

      check(accessToken != null && accessToken.length == 64,
          'authorize devuelve un accessToken de 64 hex');
      check(device['status'] == 'ACTIVE',
          'el dispositivo queda ACTIVO tras autorizar');

      final api = MySynkApi(
        baseUrl: baseUrl,
        token: accessToken,
      );

      final me = await api.getDeviceMe();
      check((me['device'] as Map<String, dynamic>)['id'] == deviceId,
          'GET /devices/me valida el token Bearer');

      // ----------------------------------------------------------------
      // Par 1: subida, idempotencia, requestedAt y borrado remoto.
      // ----------------------------------------------------------------
      final localRoot =
          await Directory.systemTemp.createTemp('mysynk_e2e_');
      final camera =
          Directory('${localRoot.path}/Camera/Subcarpeta');
      await camera.create(recursive: true);

      final textFile = File('${localRoot.path}/hola.txt');
      await textFile.writeAsString('Hola MySynk\n');

      final imageFile =
          File('${localRoot.path}/Camera/IMG_0001.txt');
      await imageFile.writeAsString('contenido de imagen\n');

      final nestedFile = File('${camera.path}/notas.txt');
      await nestedFile.writeAsString('notas anidadas\n');

      final pair1 = await api.createSyncPair(
        deviceId: deviceId,
        localPath: localRoot.path,
        devicePath: '/E2E-Flutter-$suffix',
        mode: 'BIDIRECTIONAL',
      );
      pairId1 = pair1['id'] as String;

      await client.post(
        Uri.parse('$baseUrl/api/v1/sync/$pairId1/request'),
      );

      final beforeStatus = await api.getSyncStatus(pairId1);
      check(beforeStatus['requestedAt'] != null,
          'la web puede solicitar una sincronización');

      final engine = SyncEngine(api: api, scanner: LocalScanner());

      final first = await engine.run(
        pairId: pairId1,
        localPath: localRoot.path,
      );

      check(first.errors == 0,
          'el primer ciclo no tiene errores (${first.errors})');
      check(first.uploaded >= 3,
          'el manifiesto sube archivos y carpetas (${first.uploaded})');
      check(first.conflicts == 0,
          'el primer ciclo no tiene conflictos');

      final uploadedBytes =
          await api.downloadSyncFile(pairId1, 'hola.txt');
      check(utf8.decode(uploadedBytes) == 'Hola MySynk\n',
          'el archivo subido se descarga con el mismo contenido');

      final afterStatus = await api.getSyncStatus(pairId1);
      check(afterStatus['requestedAt'] == null,
          'generar el plan limpia requestedAt');

      final second = await engine.run(
        pairId: pairId1,
        localPath: localRoot.path,
      );
      check(second.uploaded == 0 && second.conflicts == 0,
          'un segundo ciclo es idempotente');
      check(second.status == 'completed',
          'el run se cierra como completed (${second.status})');

      await textFile.delete();
      final mirror = await engine.run(
        pairId: pairId1,
        localPath: localRoot.path,
        operation: 'MIRROR',
      );
      check(mirror.deletedRemote >= 1,
          'MIRROR borra del servidor lo que ya no está en local');

      var missing = false;
      try {
        await api.downloadSyncFile(pairId1, 'hola.txt');
      } on MySynkApiException catch (error) {
        missing = error.statusCode == 404;
      }
      check(missing, 'el archivo borrado ya no existe en el espejo');

      // ----------------------------------------------------------------
      // Par 2: descarga hacia el dispositivo.
      // ----------------------------------------------------------------
      final downloadRoot =
          await Directory.systemTemp.createTemp('mysynk_download_');

      final pair2 = await api.createSyncPair(
        deviceId: deviceId,
        localPath: downloadRoot.path,
        devicePath: '/E2E-Flutter-Down-$suffix',
        mode: 'ONE_WAY_DOWNLOAD',
      );
      pairId2 = pair2['id'] as String;

      await api.uploadSyncFile(
        pairId2,
        'Remoto/bienvenida.txt',
        utf8.encode('Bienvenido desde el servidor\n'),
      );

      final downloaded = await engine.run(
        pairId: pairId2,
        localPath: downloadRoot.path,
      );

      check(downloaded.downloaded >= 1,
          'el cliente descarga lo que solo existe en el servidor');
      check(downloaded.errors == 0,
          'la descarga y su ack no producen errores');

      final downloadedFile =
          File('${downloadRoot.path}/Remoto/bienvenida.txt');
      check(await downloadedFile.exists(),
          'la descarga crea la carpeta local');
      check(await downloadedFile.readAsString() ==
              'Bienvenido desde el servidor\n',
          'la descarga conserva el contenido');

      final repeated = await engine.run(
        pairId: pairId2,
        localPath: downloadRoot.path,
      );
      check(repeated.downloaded == 0 && repeated.deletedLocal == 0,
          'la descarga es idempotente tras el ack');
    } finally {
      if (pairId1 != null) {
        try {
          await anonymousApi.deleteSyncPair(pairId1);
        } catch (_) {}
      }
      if (pairId2 != null) {
        try {
          await anonymousApi.deleteSyncPair(pairId2);
        } catch (_) {}
      }
      client.close();
    }
  });
}
