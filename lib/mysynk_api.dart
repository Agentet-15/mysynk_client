import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_auth.dart';

/// Error devuelto por la API de MySynk.
///
/// El servidor responde siempre con `{ "error": "...", "code": "..." }`.
class MySynkApiException implements Exception {
  const MySynkApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  bool get isDeviceRevoked =>
      statusCode == 403 && code == 'DEVICE_NOT_ACTIVE';

  bool get isTokenProblem =>
      statusCode == 401 ||
      code == 'DEVICE_TOKEN_REQUIRED' ||
      code == 'DEVICE_TOKEN_INVALID';

  @override
  String toString() => message;
}

class MySynkApi {
  MySynkApi({
    required this.baseUrl,
    this.token,
  });

  final String baseUrl;

  /// Token explícito. Si es null se lee de [DeviceAuth].
  final String? token;

  String get _root => baseUrl.replaceFirst(RegExp(r'/$'), '');

  Future<Map<String, String>> _headers({
    bool json = false,
    bool auth = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (auth) {
      final deviceToken = token ?? await DeviceAuth.getAccessToken();

      if (deviceToken == null) {
        throw const MySynkApiException(
          statusCode: 401,
          code: 'DEVICE_TOKEN_REQUIRED',
          message:
              'El dispositivo no tiene token. Vuelve a emparejarlo con el QR.',
        );
      }

      headers['Authorization'] = 'Bearer $deviceToken';
    }

    return headers;
  }

  void _ensureOk(http.Response response, String fallbackMessage) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = fallbackMessage;
    String code = 'HTTP_${response.statusCode}';

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final serverMessage = decoded['error'];
        final serverCode = decoded['code'];

        if (serverMessage is String && serverMessage.isNotEmpty) {
          message = serverMessage;
        }

        if (serverCode is String && serverCode.isNotEmpty) {
          code = serverCode;
        }
      }
    } catch (_) {
      // El servidor no devolvió JSON; se conserva el mensaje genérico.
    }

    throw MySynkApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }

  Map<String, dynamic> _decodeMap(
    http.Response response,
    String fallbackMessage,
  ) {
    _ensureOk(response, fallbackMessage);

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw MySynkApiException(
        statusCode: response.statusCode,
        code: 'INVALID_RESPONSE',
        message: 'Respuesta inválida del servidor.',
      );
    }

    return decoded;
  }

  List<Map<String, dynamic>> _decodeList(
    http.Response response,
    String key,
    String fallbackMessage,
  ) {
    final data = _decodeMap(response, fallbackMessage);
    final values = data[key];

    if (values is! List) {
      throw MySynkApiException(
        statusCode: response.statusCode,
        code: 'INVALID_RESPONSE',
        message: 'La respuesta no contiene la lista $key.',
      );
    }

    return values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /* ------------------------------------------------------------------ */
  /* Explorador                                                         */
  /* ------------------------------------------------------------------ */

  Future<bool> testConnection() async {
    final uri = Uri.parse('$_root/api/v1/files');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    return data is Map<String, dynamic> && data.containsKey('items');
  }

  Future<List<Map<String, dynamic>>> listFiles(String path) async {
    final uri = Uri.parse(
      '$_root/api/v1/files?path=${Uri.encodeComponent(path)}',
    );

    final response = await http.get(uri);

    return _decodeList(response, 'items', 'Error al consultar los archivos');
  }

  /* ------------------------------------------------------------------ */
  /* Emparejamiento                                                     */
  /* ------------------------------------------------------------------ */

  Future<Map<String, dynamic>> authorizePairing({
    required String token,
    required String name,
    required String type,
    String? platformIdentifier,
  }) async {
    final uri = Uri.parse('$_root/api/v1/pairing/authorize');

    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode({
        'token': token,
        'name': name,
        'type': type,
        if (platformIdentifier != null &&
            platformIdentifier.trim().isNotEmpty)
          'platformIdentifier': platformIdentifier.trim(),
      }),
    );

    return _decodeMap(
      response,
      'No se pudo autorizar el dispositivo',
    );
  }

  Future<Map<String, dynamic>> getDeviceMe() async {
    final uri = Uri.parse('$_root/api/v1/devices/me');

    final response = await http.get(
      uri,
      headers: await _headers(auth: true),
    );

    return _decodeMap(response, 'No se pudo validar el dispositivo');
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final uri = Uri.parse('$_root/api/v1/devices');

    final response = await http.get(uri);

    return _decodeList(response, 'devices', 'Error al consultar los dispositivos');
  }

  /* ------------------------------------------------------------------ */
  /* Pares de sincronización                                            */
  /* ------------------------------------------------------------------ */

  Future<List<Map<String, dynamic>>> listSyncPairs({
    String? deviceId,
  }) async {
    final query = deviceId == null || deviceId.trim().isEmpty
        ? ''
        : '?deviceId=${Uri.encodeComponent(deviceId.trim())}';

    final uri = Uri.parse('$_root/api/v1/sync$query');

    final response = await http.get(uri);

    return _decodeList(
      response,
      'pairs',
      'Error al consultar las sincronizaciones',
    );
  }

  Future<Map<String, dynamic>> createSyncPair({
    required String deviceId,
    required String localPath,
    required String devicePath,
    String mode = 'ONE_WAY_UPLOAD',
  }) async {
    final uri = Uri.parse('$_root/api/v1/sync');

    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode({
        'deviceId': deviceId,
        'localPath': localPath,
        'devicePath': devicePath,
        'mode': mode,
      }),
    );

    final data = _decodeMap(
      response,
      'No se pudo crear la sincronización',
    );
    final pair = data['pair'];

    if (pair is! Map) {
      throw MySynkApiException(
        statusCode: response.statusCode,
        code: 'INVALID_RESPONSE',
        message: 'El servidor no devolvió el par creado.',
      );
    }

    return Map<String, dynamic>.from(pair);
  }

  Future<Map<String, dynamic>> updateSyncPair({
    required String pairId,
    required Map<String, dynamic> changes,
  }) async {
    final uri = Uri.parse('$_root/api/v1/sync/${Uri.encodeComponent(pairId)}');

    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(changes),
    );

    final data = _decodeMap(
      response,
      'No se pudo actualizar la sincronización',
    );
    final pair = data['pair'];

    if (pair is! Map) {
      throw MySynkApiException(
        statusCode: response.statusCode,
        code: 'INVALID_RESPONSE',
        message: 'El servidor no devolvió el par actualizado.',
      );
    }

    return Map<String, dynamic>.from(pair);
  }

  Future<void> deleteSyncPair(String pairId) async {
    final uri = Uri.parse('$_root/api/v1/sync/${Uri.encodeComponent(pairId)}');

    final response = await http.delete(uri);

    _ensureOk(response, 'No se pudo eliminar la sincronización');
  }

  /* ------------------------------------------------------------------ */
  /* Ciclo de sincronización cliente-dirigido                           */
  /* ------------------------------------------------------------------ */

  Future<Map<String, dynamic>> getSyncStatus(String pairId) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/status',
    );

    final response = await http.get(
      uri,
      headers: await _headers(auth: true),
    );

    return _decodeMap(response, 'No se pudo consultar el estado del par');
  }

  Future<Map<String, dynamic>> createSyncPlan(
    String pairId, {
    String operation = 'SYNC',
    required List<Map<String, dynamic>> manifest,
  }) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/plan',
    );

    final response = await http.post(
      uri,
      headers: await _headers(json: true, auth: true),
      body: jsonEncode({
        'operation': operation,
        'manifest': manifest,
      }),
    );

    return _decodeMap(response, 'No se pudo generar el plan de sincronización');
  }

  Future<Map<String, dynamic>> uploadSyncFile(
    String pairId,
    String relativePath,
    List<int> bytes, {
    String? sha256,
  }) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/files'
      '?path=${Uri.encodeComponent(relativePath)}',
    );

    final headers = await _headers(auth: true);
    headers['Content-Type'] = 'application/octet-stream';
    headers['Content-Length'] = bytes.length.toString();

    if (sha256 != null && sha256.isNotEmpty) {
      headers['X-Content-SHA256'] = sha256;
    }

    final response = await http.put(
      uri,
      headers: headers,
      body: bytes,
    );

    return _decodeMap(response, 'No se pudo subir el archivo');
  }

  Future<List<int>> downloadSyncFile(
    String pairId,
    String relativePath, {
    int? rangeStart,
  }) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/files'
      '?path=${Uri.encodeComponent(relativePath)}',
    );

    final headers = await _headers(auth: true);

    if (rangeStart != null) {
      headers['Range'] = 'bytes=$rangeStart-';
    }

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 206) {
      _ensureOk(response, 'No se pudo descargar el archivo');
    }

    return response.bodyBytes;
  }

  Future<void> deleteSyncFile(
    String pairId,
    String relativePath,
  ) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/files'
      '?path=${Uri.encodeComponent(relativePath)}',
    );

    final response = await http.delete(
      uri,
      headers: await _headers(auth: true),
    );

    _ensureOk(response, 'No se pudo eliminar el archivo del servidor');
  }

  Future<void> createSyncFolder(
    String pairId,
    String relativePath,
  ) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/folders'
      '?path=${Uri.encodeComponent(relativePath)}',
    );

    final response = await http.put(
      uri,
      headers: await _headers(auth: true),
    );

    _ensureOk(response, 'No se pudo crear la carpeta en el servidor');
  }

  Future<Map<String, dynamic>> ackSyncAction(
    String pairId, {
    required String runId,
    required String path,
    required String status,
    String? hash,
    String? error,
  }) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/ack',
    );

    final response = await http.post(
      uri,
      headers: await _headers(json: true, auth: true),
      body: jsonEncode({
        'runId': runId,
        'path': path,
        'status': status,
        'hash': ?hash,
        'error': ?error,
      }),
    );

    return _decodeMap(response, 'No se pudo confirmar la acción');
  }

  Future<Map<String, dynamic>> completeSyncRun(
    String pairId,
    String runId,
  ) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/complete',
    );

    final response = await http.post(
      uri,
      headers: await _headers(json: true, auth: true),
      body: jsonEncode({'runId': runId}),
    );

    return _decodeMap(response, 'No se pudo cerrar el ciclo');
  }

  Future<void> requestSync(String pairId) async {
    final uri = Uri.parse(
      '$_root/api/v1/sync/${Uri.encodeComponent(pairId)}/request',
    );

    final response = await http.post(uri);

    _ensureOk(response, 'No se pudo solicitar la sincronización');
  }
}
