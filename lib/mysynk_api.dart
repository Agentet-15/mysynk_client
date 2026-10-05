import 'dart:convert';

import 'package:http/http.dart' as http;

class MySynkApi {
  MySynkApi({
    required this.baseUrl,
  });

  final String baseUrl;

  Future<bool> testConnection() async {
    final uri = Uri.parse('$baseUrl/api/v1/files');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    return data is Map<String, dynamic> &&
        data.containsKey('items');
  }

  Future<List<Map<String, dynamic>>> listFiles(String path) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/files?path=${Uri.encodeComponent(path)}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al consultar los archivos');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    final items = data['items'];

    if (items is! List) {
      throw Exception(
        'La respuesta no contiene una lista de archivos',
      );
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> authorizePairing({
    required String token,
    required String name,
    required String type,
    String? platformIdentifier,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/pairing/authorize');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': token,
        'name': name,
        'type': type,
        if (platformIdentifier != null &&
            platformIdentifier.trim().isNotEmpty)
          'platformIdentifier': platformIdentifier.trim(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo autorizar el dispositivo');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    return data;
  }


  Future<List<Map<String, dynamic>>> listSyncPairs() async {
    final uri = Uri.parse('$baseUrl/api/v1/sync');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al consultar las sincronizaciones');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    final pairs = data['pairs'];

    if (pairs is! List) {
      throw Exception(
        'La respuesta no contiene una lista de sincronizaciones',
      );
    }

    return pairs
        .whereType<Map>()
        .map((pair) => Map<String, dynamic>.from(pair))
        .toList();
  }

  Future<Map<String, dynamic>> createSyncPair({
    required String deviceId,
    required String localPath,
    required String devicePath,
    String mode = 'ONE_WAY_UPLOAD',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/sync');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'localPath': localPath,
        'devicePath': devicePath,
        'mode': mode,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo crear la sincronización');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    final pair = data['pair'];

    if (pair is! Map) {
      throw Exception(
        'La respuesta no contiene la sincronización creada',
      );
    }

    return Map<String, dynamic>.from(pair);
  }

  Future<Map<String, dynamic>> updateSyncPair({
    required String pairId,
    required Map<String, dynamic> changes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/sync/$pairId');

    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(changes),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo actualizar la sincronización');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    final pair = data['pair'];

    if (pair is! Map) {
      throw Exception(
        'La respuesta no contiene la sincronización actualizada',
      );
    }

    return Map<String, dynamic>.from(pair);
  }

  Future<void> deleteSyncPair(String pairId) async {
    final uri = Uri.parse('$baseUrl/api/v1/sync/$pairId');

    final response = await http.delete(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo eliminar la sincronización');
    }
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final uri = Uri.parse('$baseUrl/api/v1/devices');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al consultar los dispositivos');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor');
    }

    final devices = data['devices'];

    if (devices is! List) {
      throw Exception(
        'La respuesta no contiene una lista de dispositivos',
      );
    }

    return devices
        .whereType<Map>()
        .map((device) => Map<String, dynamic>.from(device))
        .toList();
  }
}
